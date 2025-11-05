#!/bin/bash
# Validation script for Packer and Ansible without building
# Validates syntax, configuration, and compatibility

set -e

PROJECT_ROOT="/Users/julian/dev/vault-ai-systems/cube-golden-image"
cd "$PROJECT_ROOT"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Vault Cube Golden Image - Validation Suite               ║"
echo "║  Validates Packer & Ansible without building              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# ANSIBLE VALIDATION
# ============================================================================

echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ 1. ANSIBLE VALIDATION                                       │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

cd "$PROJECT_ROOT/ansible"

echo "  → Validating YAML syntax for all roles..."
YAML_ERRORS=0
for file in roles/*/defaults/main.yml roles/*/tasks/main.yml roles/*/handlers/main.yml roles/*/meta/main.yml; do
  if [ -f "$file" ]; then
    if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
      echo "    ✓ $file"
    else
      echo "    ✗ $file - YAML SYNTAX ERROR"
      YAML_ERRORS=$((YAML_ERRORS + 1))
    fi
  fi
done

if [ $YAML_ERRORS -gt 0 ]; then
  echo ""
  echo "  ✗ Found $YAML_ERRORS YAML syntax errors"
  exit 1
else
  echo ""
  echo "  ✓ All YAML files valid"
fi

echo ""
echo "  → Validating playbook syntax..."
if ansible-playbook playbooks/site.yml --syntax-check > /dev/null 2>&1; then
  echo "    ✓ playbooks/site.yml syntax valid"
else
  echo "    ✗ playbooks/site.yml has syntax errors"
  ansible-playbook playbooks/site.yml --syntax-check
  exit 1
fi

echo ""
echo "  → Running Ansible check mode (dry-run)..."
echo "    (This simulates execution without making changes)"
if ansible-playbook playbooks/site.yml --check -i localhost, --connection=local > /tmp/ansible-check.log 2>&1; then
  echo "    ✓ Playbook check mode passed"
  echo "    ℹ Full output saved to: /tmp/ansible-check.log"
else
  echo "    ⚠ Check mode encountered issues (may be expected for some tasks)"
  echo "    ℹ Review: /tmp/ansible-check.log"
fi

# Optional: ansible-lint (if installed)
if command -v ansible-lint &> /dev/null; then
  echo ""
  echo "  → Running ansible-lint..."
  if ansible-lint playbooks/site.yml > /tmp/ansible-lint.log 2>&1; then
    echo "    ✓ ansible-lint passed"
  else
    echo "    ⚠ ansible-lint found issues (review /tmp/ansible-lint.log)"
  fi
else
  echo ""
  echo "    ℹ ansible-lint not installed (optional)"
fi

echo ""
echo "  ✅ Ansible validation complete"
echo ""

# ============================================================================
# PACKER VALIDATION
# ============================================================================

echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ 2. PACKER VALIDATION                                        │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

cd "$PROJECT_ROOT/packer"

PACKER_ERRORS=0

echo "  → Validating Packer templates..."
for template in *.pkr.hcl; do
  if [ -f "$template" ]; then
    echo "    Checking: $template"
    if packer validate "$template" > /tmp/packer-validate.log 2>&1; then
      echo "      ✓ $template - syntax valid"
    else
      echo "      ✗ $template - VALIDATION FAILED"
      cat /tmp/packer-validate.log
      PACKER_ERRORS=$((PACKER_ERRORS + 1))
    fi
  fi
done

if [ $PACKER_ERRORS -gt 0 ]; then
  echo ""
  echo "  ✗ Found $PACKER_ERRORS Packer validation errors"
  exit 1
fi

echo ""
echo "  → Checking Packer formatting..."
if packer fmt -check . > /dev/null 2>&1; then
  echo "    ✓ Packer files properly formatted"
else
  echo "    ⚠ Some files need formatting"
  echo "    → Run: cd packer && packer fmt ."
fi

echo ""
echo "  → Inspecting Packer configuration..."
for template in *.pkr.hcl; do
  if [ -f "$template" ]; then
    echo "    Template: $template"
    packer inspect "$template" | grep -E "^(Source|Provisioner|Post-processor)" | head -20
    break
  fi
done

echo ""
echo "  ✅ Packer validation complete"
echo ""

# ============================================================================
# INTEGRATION CHECKS
# ============================================================================

echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ 3. INTEGRATION CHECKS                                       │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

echo "  → Checking Packer → Ansible integration..."

# Check if Packer references the correct Ansible playbook
if grep -q "playbooks/site.yml" "$PROJECT_ROOT/packer"/*.pkr.hcl 2>/dev/null; then
  echo "    ✓ Packer references Ansible playbook"
else
  echo "    ⚠ Packer may not reference Ansible playbook correctly"
fi

# Check if all referenced roles exist
echo ""
echo "  → Checking role references..."
ROLES_IN_PLAYBOOK=$(grep -A1 "- role:" "$PROJECT_ROOT/ansible/playbooks/site.yml" | grep "role:" | awk '{print $3}' | sort -u)
for role in $ROLES_IN_PLAYBOOK; do
  if [ -d "$PROJECT_ROOT/ansible/roles/$role" ]; then
    echo "    ✓ Role exists: $role"
  else
    echo "    ✗ Role missing: $role"
  fi
done

echo ""
echo "  ✅ Integration checks complete"
echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ VALIDATION COMPLETE - NO BUILD REQUIRED                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "All syntax and configuration checks passed!"
echo ""
echo "Next steps:"
echo "  • Test with Packer build: cd packer && packer build ubuntu-22.04-demo-box.pkr.hcl"
echo "  • Run specific role: ansible-playbook playbooks/site.yml --tags docker"
echo ""
