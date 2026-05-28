#!/bin/bash
set -e

echo ""
echo "================================================="
echo "  Crystal DevOps Demo - Push para GitHub"
echo "================================================="
echo ""

git add -A

git status

git commit -m "feat: Crystal DevOps Demo v1.0.0 - sistema completo para apresentacao DevOps"

git branch -M main

git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/nunesxfx/Apresenta-o-DevOps.git

echo ""
echo "Fazendo push para https://github.com/nunesxfx/Apresenta-o-DevOps.git ..."
echo ""

git push -u origin main

echo ""
echo "================================================="
echo "  SUCESSO! Repositorio publicado no GitHub"
echo "  https://github.com/nunesxfx/Apresenta-o-DevOps"
echo "================================================="
echo ""
