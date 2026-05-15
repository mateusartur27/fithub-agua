# Contexto do Agente (Antigravity)

Este arquivo define as diretrizes de comportamento, autonomia e arquitetura para o desenvolvimento do **FitHub Água**.

## 1. Diretrizes de Autonomia
- **Autonomia Máxima**: O Antigravity tem permissão para planejar, executar, orquestrar fluxos e testar autonomamente.
- **Integração Codex**: A lógica pesada do backend/algoritmos deve ser assistida pelo CLI do `codex` (garantindo o uso da linguagem mais otimizada).
- **Integração UI**: A interface deve ser desenvolvida usando o modelo Gemini 3.1 Pro (High) focado em **estética premium, glassmorphism e animações dinâmicas**.

## 2. Ecossistema AHUB (Supabase)
- O projeto não terá banco próprio autônomo, ele será um "módulo" dentro do banco de dados centralizado **AHUB**.
- Todas as tabelas criadas para o FitHub Água devem ser sufixadas ou associadas de forma clara para não conflitar com outros apps do AHUB.
- Autenticação e Login devem utilizar as tabelas globais do AHUB.

## 3. GitHub e CI/CD
- O projeto deve ser publicado como um repositório público usando o `gh cli`.

## 4. Stack do Projeto
- **Mobile**: Flutter (Dart)
- **API/Proxy**: Node.js
- **IA**: Google Gemini (via proxy Node.js)
- **Recursos Nativos**: Microfone (`speech_to_text`)
