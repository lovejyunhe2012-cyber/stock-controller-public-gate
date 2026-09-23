import json
import os
import re
import sys
from pathlib import Path

OUTPUT = Path('public_minimal/protected_ref_result.json')
allowed_ref = 'refs/heads/main'
actual_ref = os.getenv('GITHUB_REF', '')
actual_sha = os.getenv('GITHUB_SHA', '')
ref_protected = os.getenv('GITHUB_REF_PROTECTED', '').lower() == 'true'
sha_valid = re.fullmatch(r'[0-9a-f]{40}', actual_sha) is not None

checks = {
    'approved_ref': actual_ref == allowed_ref,
    'protected_ref': ref_protected,
    'exact_sha_present': sha_valid,
}
failed = [name for name, ok in checks.items() if not ok]
result = {
    'decision': 'ALLOW' if not failed else 'BLOCK',
    'reason': 'PROTECTED_APPROVED_REF_AND_EXACT_SHA' if not failed else 'ADMISSION_CHECK_FAILED',
    'failed_checks': failed,
    'ref': actual_ref,
    'sha': actual_sha,
    'ref_protected': ref_protected,
    'override_effect': 'IGNORED',
}
OUTPUT.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result))
sys.exit(0 if result['decision'] == 'ALLOW' else 2)
