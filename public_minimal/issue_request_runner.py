import json
import os
import sys
import urllib.request
from pathlib import Path

PREFIX = 'RUN:'
OUTPUT = Path('public_minimal/issue_request_result.json')
repo = os.environ['GITHUB_REPOSITORY']
token = os.environ['GITHUB_TOKEN']
url = f'https://api.github.com/repos/{repo}/issues?state=open&sort=created&direction=desc&per_page=100'
req = urllib.request.Request(url, headers={
    'Authorization': f'Bearer {token}',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
})
with urllib.request.urlopen(req, timeout=20) as r:
    issues = json.loads(r.read().decode('utf-8'))

candidate = None
for issue in issues:
    if 'pull_request' in issue:
        continue
    if str(issue.get('title', '')).startswith(PREFIX):
        candidate = issue
        break

if candidate is None:
    result = {'decision': 'BLOCK', 'reason': 'NO_EXECUTION_REQUEST', 'override_effect': 'IGNORED'}
else:
    try:
        data = json.loads(candidate.get('body') or '{}')
    except json.JSONDecodeError:
        data = {}
    checks = data.get('checks', {})
    if not isinstance(checks, dict) or not checks:
        result = {'decision': 'BLOCK', 'reason': 'INVALID_EXECUTION_REQUEST', 'request_issue': candidate['number'], 'override_effect': 'IGNORED'}
    else:
        failed = [k for k, v in checks.items() if v is not True]
        result = {
            'decision': 'ALLOW' if not failed else 'BLOCK',
            'reason': 'ALL_CHECKS_PASS' if not failed else 'CHECKS_FAILED',
            'failed_checks': failed,
            'request_issue': candidate['number'],
            'override_effect': 'IGNORED',
        }

OUTPUT.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result))
sys.exit(0 if result['decision'] == 'ALLOW' else 2)
