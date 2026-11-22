#!/usr/bin/env python3
"""NITRO WHEELZ coordination inbox: what is new on GitHub since the last ACK. READ-ONLY.

Why this exists (docs/dev/COMMUNICATION_AUDIT_20261122.md): in Claude Code web sessions
`gh issue view`, `gh issue list` and `gh pr list` FAIL (HTTP 403, GraphQL is blocked), while
the REST API works. This script uses `gh api` (REST) only, needs no GraphQL and no token
handling of its own, and prints in one screen what an agent must read before it acts:

  * open issues with their comment counts,
  * the comments newer than the last READ-UP-TO watermark that an agent wrote into its own
    ACK (so there is no local state: the ACK itself carries the watermark),
  * markers an agent must not miss (CLAIM, ACK, OWNER_ANSWER, OWNER_DECISION, OWNER_QA_PACKET,
    BLOCKED, handshake tokens) and handshake tokens that still have no ACK,
  * open pull requests and the heads of the agent / dev branches.

  python3 tools/coord/inbox.py                      # everything new since my last ACK
  python3 tools/coord/inbox.py --issues 26,27       # only these issues
  python3 tools/coord/inbox.py --full               # full comment bodies, not first lines
  python3 tools/coord/inbox.py --since 2026-11-22T12:00:00Z --agent CHATGPT

Author convention it relies on (proposed in the audit): the first line of every comment
written by an agent is `FROM: CLAUDE | CHATGPT | OWNER` (the GitHub login is the owner's
account for all of them, so the login cannot tell who wrote it).
"""
import argparse
import json
import re
import subprocess
import sys

MARKERS = ["CLAIM by", "OWNER_ANSWER", "OWNER_DECISION", "OWNER_QA_PACKET", "BLOCKED",
           "OWNER DECISION", "OWNER OVERRIDE", "OWNER REQUEST", "HANDSHAKE", "STATUS:"]
TOKEN = re.compile(r"NW-QA-HANDSHAKE-[0-9A-Z-]+")
WATERMARK = re.compile(r"READ-UP-TO:\s*(?:#?(\d+)\s*[:=]\s*)?(\d{6,})", re.I)


def gh(path):
    out = subprocess.run(["gh", "api", "--paginate", path], capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit("gh api %s failed: %s" % (path, out.stderr.strip()[:300]))
    text = out.stdout.strip()
    if not text:
        return []
    # --paginate concatenates JSON arrays: ][ -> ,
    text = re.sub(r"\]\s*\[", ",", text)
    return json.loads(text)


def repo_slug(arg):
    if arg:
        return arg
    url = subprocess.run(["git", "remote", "get-url", "origin"], capture_output=True, text=True).stdout.strip()
    m = re.search(r"github\.com[:/](.+?)(?:\.git)?$", url)
    if not m:
        sys.exit("cannot find the GitHub repository; pass --repo owner/name")
    return m.group(1)


def first_line(body):
    for line in body.splitlines():
        if line.strip():
            return line.strip()[:160]
    return ""


def is_from(body, agent):
    head = "\n".join(body.splitlines()[:3]).upper()
    return ("FROM: " + agent.upper()) in head or ("FROM " + agent.upper()) in head


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo")
    ap.add_argument("--issues", help="comma separated issue numbers (default: every open issue)")
    ap.add_argument("--since", help="ISO time: show comments newer than this (overrides the watermark)")
    ap.add_argument("--agent", default="CLAUDE", help="whose ACK carries the watermark (CLAUDE | CHATGPT)")
    ap.add_argument("--full", action="store_true")
    ap.add_argument("--no-git", action="store_true", help="skip pull requests and branches")
    args = ap.parse_args()
    repo = repo_slug(args.repo)
    wanted = {int(x) for x in args.issues.split(",")} if args.issues else None

    issues = [i for i in gh("repos/%s/issues?state=open&per_page=100" % repo) if "pull_request" not in i]
    issues.sort(key=lambda i: i["number"])
    print("# INBOX %s @ now   (REST only; READ-ONLY)" % repo)
    print("open issues: " + ", ".join("#%d(%d)" % (i["number"], i["comments"]) for i in issues))
    acked_tokens, request_tokens = set(), {}
    for issue in issues:
        n = issue["number"]
        if wanted and n not in wanted:
            continue
        comments = gh("repos/%s/issues/%d/comments?per_page=100" % (repo, n)) if issue["comments"] else []
        mark = 0
        for c in comments:
            if is_from(c["body"], args.agent) or c["body"].startswith("ACK "):
                for m in WATERMARK.finditer(c["body"]):
                    if m.group(1) is None or int(m.group(1)) == n:
                        mark = max(mark, int(m.group(2)))
            for t in TOKEN.findall(c["body"]):
                if c["body"].startswith("ACK ") and t in c["body"].split("\n", 1)[0]:
                    acked_tokens.add(t)
                else:
                    request_tokens.setdefault(t, (n, c["id"], c["created_at"]))
        if args.since:
            fresh = [c for c in comments if c["created_at"] > args.since]
        else:
            fresh = [c for c in comments if c["id"] > mark]
        print("\n## #%d  %s   [%d comments, watermark %s, %d new]" % (n, issue["title"][:90], len(comments), mark or "none", len(fresh)))
        for c in fresh:
            flags = [m.strip() for m in MARKERS if m in c["body"][:400]]
            if c["body"].startswith("ACK "):
                flags.insert(0,"ACK")
            print("- %d  %s  %s  %s" % (c["id"], c["created_at"], c["user"]["login"], ("[" + ", ".join(flags) + "]") if flags else ""))
            if args.full:
                print("  " + c["body"].replace("\n", "\n  "))
            else:
                print("  " + first_line(c["body"]))
        if comments:
            print("  -> when you ACK, write: READ-UP-TO: #%d:%d" % (n, comments[-1]["id"]))
    open_tokens = {t: v for t, v in request_tokens.items() if t not in acked_tokens}
    if open_tokens:
        print("\n## handshake tokens WITHOUT an ACK line")
        for t, (n, cid, when) in open_tokens.items():
            print("- %s  asked in #%d comment %d at %s" % (t, n, cid, when))
    if not args.no_git:
        prs = gh("repos/%s/pulls?state=open&per_page=50" % repo)
        print("\n## open pull requests")
        for p in prs:
            print("- #%d %s -> %s %s%s" % (p["number"], p["head"]["ref"], p["base"]["ref"], "[draft] " if p.get("draft") else "", p["title"][:70]))
        print("\n## branches (agent/* and the dev branch)")
        for b in gh("repos/%s/branches?per_page=100" % repo):
            if b["name"].startswith("agent/") or b["name"].startswith("ccr-"):
                print("- %-52s %s" % (b["name"], b["commit"]["sha"][:10]))


if __name__ == "__main__":
    main()
