import json
import os
import re
import sys
from pathlib import Path

OUTPUT = Path('public_minimal/t1_shadow_result.json')
ALLOWED_REF = 'refs/heads/main'

analysis_run_identity = os.getenv('T1_ANALYSIS_RUN_ID', '').strip()
input_binding_digest = os.getenv('T1_INPUT_BINDING_DIGEST', '').strip().lower()
externally_approved_sha = os.getenv('T1_EXTERNALLY_APPROVED_SHA', '').strip().lower()
actual_ref = os.getenv('GITHUB_REF', '').strip()
actual_sha = os.getenv('GITHUB_SHA', '').strip().lower()
ref_protected = os.getenv('GITHUB_REF_PROTECTED', '').strip().lower() == 'true'
daily_actor = os.getenv('GITHUB_ACTOR', '').strip()
contents_write_http = os.getenv('T1_CONTENTS_WRITE_HTTP', '').strip()
administration_http = os.getenv('T1_ADMINISTRATION_HTTP', '').strip()

sha40 = re.compile(r'^[0-9a-f]{40}$')
sha256 = re.compile(r'^[0-9a-f]{64}$')

checks = {
    'analysis_run_identity_present': bool(analysis_run_identity),
    'input_binding_digest_valid': sha256.fullmatch(input_binding_digest) is not None,
    'approved_ref': actual_ref == ALLOWED_REF,
    'protected_ref': ref_protected,
    'actual_sha_valid': sha40.fullmatch(actual_sha) is not None,
    'externally_approved_sha_valid': sha40.fullmatch(externally_approved_sha) is not None,
    'approved_sha_match': actual_sha == externally_approved_sha,
    'daily_principal_contents_write_denied': contents_write_http == '403',
    'daily_principal_administration_denied': administration_http == '403',
    'maintenance_credential_excluded': daily_actor == 'github-actions[bot]',
}

failed = [name for name, ok in checks.items() if not ok]
if not failed:
    reason = 'T1_SHADOW_ELIGIBLE_APPROVED_PROTECTED_EXACT_SHA_AND_PERMISSION_BOUNDARY'
elif 'approved_sha_match' in failed:
    reason = 'APPROVED_SHA_MISMATCH'
elif 'approved_ref' in failed:
    reason = 'UNAPPROVED_REF'
elif 'protected_ref' in failed:
    reason = 'UNPROTECTED_REF'
elif 'maintenance_credential_excluded' in failed:
    reason = 'MAINTENANCE_CREDENTIAL_PRESENT_OR_DAILY_ACTOR_INVALID'
else:
    reason = 'T1_SHADOW_ADMISSION_CHECK_FAILED'

result = {
    'analysis_run_identity': analysis_run_identity,
    'input_binding_digest': input_binding_digest,
    'controller_exact_sha': actual_sha,
    'externally_approved_sha': externally_approved_sha,
    'protected_ref_state': ref_protected,
    'effective_daily_principal_permissions': {
        'contents_write': 'NO' if contents_write_http == '403' else 'NOT_PROVEN',
        'administration': 'NO' if administration_http == '403' else 'NOT_PROVEN',
        'actions_dispatch': 'YES_PROVEN_BY_CURRENT_DOWNSTREAM_INVOCATION',
        'daily_actor': daily_actor,
    },
    'decision_allow_or_block': 'ALLOW' if not failed else 'BLOCK',
    'machine_reason': reason,
    'failed_checks': failed,
    'ref': actual_ref,
    'override_effect': 'IGNORED',
}

OUTPUT.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n', encoding='utf-8')
print(json.dumps(result, sort_keys=True))
sys.exit(0 if result['decision_allow_or_block'] == 'ALLOW' else 2)
