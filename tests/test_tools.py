import importlib.util
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

check = load("check_project")
version = load("bump_version")
packager = load("package_release")

class ArtGateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.base = self.root / "assets/references/approved"
        self.base.mkdir(parents=True)
        self.manifest = self.root / "assets/approved_assets.json"
        self.asset = self.base / "car.png"
        self.asset.write_bytes(b"ORIGINAL")
        self.entry = {"id":"car-v1","path":"assets/references/approved/car.png","sha256":hashlib.sha256(b"ORIGINAL").hexdigest()}
        self.write([self.entry])

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, entries):
        self.manifest.write_text(json.dumps({"schema_version":1,"assets":entries}))

    def test_original_passes(self):
        self.assertFalse(check.validate_assets(self.root, [self.entry]))

    def test_raw_edit_rejected(self):
        self.asset.write_bytes(b"CHANGED")
        self.assertTrue(check.validate_assets(self.root, [self.entry]))

    def test_rehash_bypass_rejected(self):
        self.asset.write_bytes(b"CHANGED")
        newer = dict(self.entry)
        newer["sha256"] = hashlib.sha256(b"CHANGED").hexdigest()
        self.write([newer])
        self.assertTrue(check.validate_assets(self.root, [self.entry]))

    def test_unregistered_file_rejected(self):
        (self.base / "surprise.png").write_bytes(b"NEW")
        self.assertTrue(check.validate_assets(self.root, [self.entry]))

    def test_delete_both_rejected(self):
        self.asset.unlink()
        self.write([])
        self.assertTrue(check.validate_assets(self.root, [self.entry]))

    def test_symlink_bypass_rejected(self):
        self.asset.unlink()
        self.asset.symlink_to(self.manifest)
        self.assertTrue(check.validate_assets(self.root, [self.entry]))

class ToolsTests(unittest.TestCase):
    def test_semver(self):
        self.assertEqual(version.new_version("0.1.0","patch"),"0.1.1")
        self.assertEqual(version.new_version("0.1.0","minor"),"0.2.0")
        self.assertEqual(version.new_version("0.9.0","major"),"1.0.0")

    def test_source_package_is_immutable(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td) / "repo"
            root.mkdir()
            (root/"VERSION").write_text("0.1.0")
            (root/"project.json").write_text(json.dumps({"game_name":"Sample","game_slug":"sample","game_version":"0.1.0"}))
            (root/"hello.txt").write_text("HELLO")
            dest = Path(td)/"builds"
            artifact = packager.package(root,dest,"Source")
            self.assertTrue(artifact.exists())
            self.assertTrue((dest/(artifact.name+".sha256")).exists())
            with self.assertRaises(FileExistsError):
                packager.package(root,dest,"Source")

if __name__ == "__main__":
    unittest.main()

