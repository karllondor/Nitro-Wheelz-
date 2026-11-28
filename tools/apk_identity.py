#!/usr/bin/env python3
"""Print or verify the update identity of an Android APK (issue #68, one stable QA package).

    python3 tools/apk_identity.py APK                         # prints package, versionCode, versionName, cert SHA-256
    python3 tools/apk_identity.py APK --expect-package P --expect-cert SHA256 [--min-version-code N]

Android installs an APK as an UPDATE of the installed app (keeping its saves) only when the package name is the same,
the signing certificate is the same and versionCode is not lower. This tool reads those three facts from the APK
itself: the binary AndroidManifest.xml (small AXML parser, no Android SDK needed) and the v1 signature block
(META-INF/*.RSA|DSA|EC, certificate read with `keytool -printcert`). Exit 1 on any mismatch.
Standard library + keytool (Java) only, so it runs the same locally and in CI.
"""
import argparse
import re
import struct
import subprocess
import sys
import tempfile
import zipfile

RES_STRING_POOL = 0x0001
RES_XML_START_ELEMENT = 0x0102
TYPE_STRING = 0x03
TYPE_INT_DEC = 0x10
TYPE_INT_HEX = 0x11


def _string_pool(data, off):
    _type, header_size, _size = struct.unpack_from("<HHI", data, off)
    count, _styles, flags, strings_start, _styles_start = struct.unpack_from("<IIIII", data, off + 8)
    utf8 = bool(flags & (1 << 8))
    offsets = struct.unpack_from("<%dI" % count, data, off + header_size)
    base = off + strings_start
    out = []
    for o in offsets:
        p = base + o
        if utf8:
            n = data[p]
            p += 2 if n & 0x80 else 1  # utf-16 length (skipped)
            n = data[p]
            if n & 0x80:
                n = ((n & 0x7F) << 8) | data[p + 1]
                p += 2
            else:
                p += 1
            out.append(data[p:p + n].decode("utf-8", "replace"))
        else:
            n = struct.unpack_from("<H", data, p)[0]
            p += 2
            if n & 0x8000:
                n = ((n & 0x7FFF) << 16) | struct.unpack_from("<H", data, p)[0]
                p += 2
            out.append(data[p:p + 2 * n].decode("utf-16-le", "replace"))
    return out


def manifest_facts(axml):
    """package / versionCode / versionName of the <manifest> element."""
    strings = []
    off = 8  # file header (RES_XML_TYPE)
    while off < len(axml):
        ctype, header_size, size = struct.unpack_from("<HHI", axml, off)
        if ctype == RES_STRING_POOL:
            strings = _string_pool(axml, off)
        elif ctype == RES_XML_START_ELEMENT:
            ext = off + header_size
            _ns, name, attr_start, attr_size, attr_count = struct.unpack_from("<iiHHH", axml, ext)
            if strings[name] == "manifest":
                facts = {}
                a = ext + attr_start
                for i in range(attr_count):
                    _ans, aname, raw, _vsize, _res0, vtype, vdata = struct.unpack_from("<iiiHBBI", axml, a + i * attr_size)
                    key = strings[aname]
                    if vtype == TYPE_STRING or (raw >= 0 and vtype not in (TYPE_INT_DEC, TYPE_INT_HEX)):
                        facts[key] = strings[raw] if raw >= 0 else strings[vdata]
                    else:
                        facts[key] = vdata
                return facts
        if size <= 0:
            break
        off += size
    raise ValueError("no <manifest> element in AndroidManifest.xml")


def cert_sha256(apk_zip):
    names = [n for n in apk_zip.namelist() if re.match(r"META-INF/[^/]+\.(RSA|DSA|EC)$", n)]
    if not names:
        raise ValueError("no v1 signature block (META-INF/*.RSA) in the APK")
    with tempfile.NamedTemporaryFile(suffix=".rsa") as f:
        f.write(apk_zip.read(names[0]))
        f.flush()
        out = subprocess.run(["keytool", "-printcert", "-file", f.name], capture_output=True, text=True, check=True).stdout
    m = re.search(r"SHA256:\s*([0-9A-F:]{95})", out)
    if not m:
        raise ValueError("keytool printed no SHA-256 fingerprint")
    owner = re.search(r"Owner:\s*(.*)", out)
    return m.group(1), owner.group(1).strip() if owner else ""


def norm(fp):
    return fp.replace(":", "").strip().upper()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("apk")
    ap.add_argument("--expect-package")
    ap.add_argument("--expect-cert", help="SHA-256 of the signing certificate (colons optional)")
    ap.add_argument("--min-version-code", type=int, help="the APK's versionCode must be greater than or equal to this")
    args = ap.parse_args()
    with zipfile.ZipFile(args.apk) as z:
        facts = manifest_facts(z.read("AndroidManifest.xml"))
        cert, owner = cert_sha256(z)
    pkg = str(facts.get("package", ""))
    code = int(facts.get("versionCode", -1))
    name = str(facts.get("versionName", ""))
    print("APK_PACKAGE=%s" % pkg)
    print("APK_VERSION_CODE=%d" % code)
    print("APK_VERSION_NAME=%s" % name)
    print("APK_CERT_SHA256=%s" % cert)
    print("APK_CERT_OWNER=%s" % owner)
    errors = []
    if args.expect_package and pkg != args.expect_package:
        errors.append("package %s, expected %s (a different package installs as a NEW app)" % (pkg, args.expect_package))
    if args.expect_cert and norm(cert) != norm(args.expect_cert):
        errors.append("signing certificate %s, expected %s (Android refuses the update)" % (cert, args.expect_cert))
    if args.min_version_code is not None and code < args.min_version_code:
        errors.append("versionCode %d is lower than %d (Android refuses a downgrade)" % (code, args.min_version_code))
    for e in errors:
        print("FAIL: " + e)
    if errors:
        return 1
    if args.expect_package or args.expect_cert or args.min_version_code is not None:
        print("PASS: APK identity - same package, same certificate, versionCode not lower: installs as an update")
    return 0


if __name__ == "__main__":
    sys.exit(main())
