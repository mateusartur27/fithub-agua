# OpenSpec: FitHub Água

## 1. Arquitetura do Sistema
- **Frontend**: Flutter (Mobile Híbrido).
- **Backend/Proxy**: Node.js (Express) focado em roteamento e segurança de API.
- **Banco de Dados**: Supabase (Cluster Centralizado `AHUB`).
- **Inteligência Artificial**: Google Gemini API via pacote `@google/generative-ai`.
- **Recurso Nativo Principal**: Microfone (`speech_to_text`).

## 2. Estrutura de Banco de Dados (AHUB)
Como o projeto utiliza o banco global AHUB, as tabelas serão prefixadas com `fithub_agua_` para evitar colisões.

### Tabelas Planejadas:
- `fithub_agua_records`:
  - `id` (uuid, pk)
  - `user_id` (uuid, fk para ahub auth.users ou tabela central de usuários ahub)
  - `amount_ml` (int)
  - `recorded_at` (timestampz)
- `fithub_agua_reminders`:
  - `id` (uuid, pk)
  - `user_id` (uuid)
  - `cron_schedule` (text)
  - `is_active` (boolean)

## 3. Fluxo de Interação de IA
1. O usuário pressiona o botão de microfone e fala "Bebi 2 copos de água".
2. O pacote `speech_to_text` converte para a string: "Bebi 2 copos de água".
3. O Flutter envia a requisição POST com o histórico recente de chat para o Node.js (`/api/chat`).
4. O Node.js injeta o *System Prompt* (instruções médicas/hidratação e regras de parse) e repassa para o Gemini API.
5. O Gemini retorna a resposta em linguagem natural ("Registrado! Que ótimo.") e um payload estruturado invisível (`{"action": "add_water", "amount": 500}`).
6. O Node.js processa a ação, salva no Supabase AHUB e retorna ao Flutter.
7. A View (Flutter) atualiza o Dashboard reativamente (Riverpod/Provider).
