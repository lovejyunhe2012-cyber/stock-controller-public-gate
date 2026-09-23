import json
from pathlib import Path

INPUT = Path('public_minimal/input.json')
OUTPUT = Path('public_minimal/result.json')

data = json.loads(INPUT.read_text(encoding='utf-8'))
checks = data.get('checks', {})

if not isinstance(checks, dict) or not checks:
    result = {'decision': 'BLOCK', 'reason': 'MISSING_OR_INVALID_CHECKS'}
else:
    failed = [name for name, value in checks.items() if value is not True]
    result = {
        'decision': 'ALLOW' if not failed else 'BLOCK',
        'reason': 'ALL_CHECKS_PASS' if not failed else 'CHECKS_FAILED',
        'failed_checks': failed,
        'override_effect': 'IGNORED'
    }

OUTPUT.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result))

if result['decision'] != 'ALLOW':
    raise SystemExit(2)
