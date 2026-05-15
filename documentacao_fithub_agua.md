# Documentação de Projeto: FitHub Água 💧

**Ecossistema:** FitHub - Ecossistema de Aplicativos Fitness
**Desenvolvedor:** Mateus
**Área de Atuação:** Hidratação Inteligente com Assistente de IA

---

## 1. Visão Geral do Aplicativo (A Ideia)

O **FitHub Água** é um assistente pessoal de hidratação baseado em **Inteligência Artificial conversacional**. Diferente de apps tradicionais de controle de água, toda a interação acontece por meio de um **chat inteligente**, onde o usuário conversa naturalmente (por texto ou por voz) com uma IA que o ajuda a manter sua hidratação em dia.

**Como vai funcionar na prática:**

*   **Chat de IA como Centro de Tudo:** A tela principal do app é um chat. O usuário interage naturalmente com a IA para registrar consumo, tirar dúvidas, pedir cálculos e agendar lembretes. Exemplos de interações:
    *   *"Acabei de beber um copo de 300ml."* → A IA registra e atualiza o dashboard automaticamente.
    *   *"Quanto de água eu preciso beber por dia? Eu peso 75kg."* → A IA calcula a meta ideal (ex: ~2,6L) e configura no app.
    *   *"Me lembra de beber água a cada 1 hora."* → A IA agenda lembretes periódicos que chegam como mensagens no chat (e como notificação push se o app estiver fechado).
    *   *"Estou me sentindo tonto e com dor de cabeça."* → A IA identifica possíveis sintomas de desidratação e orienta o usuário.
*   **Dashboard de Progresso:** Além do chat, o app terá uma tela de dashboard com um contador visual mostrando o progresso diário em tempo real (ex: "Você já bebeu 1,8L de 2,5L hoje"). Cada registro feito via chat atualiza automaticamente o dashboard.
*   **Lembretes Inteligentes:** Os lembretes agendados pelo usuário no chat chegam como mensagens da IA no próprio chat. Caso o app esteja fechado, o lembrete chega como uma notificação push no celular.
*   **Interação por Voz:** O usuário poderá usar o microfone do celular para falar diretamente com a IA, sem precisar digitar. Ideal para momentos em que está na academia, correndo ou com as mãos ocupadas.

## 2. Stack Tecnológica

*   **Mobile / Frontend:** Flutter (Dart) - Framework híbrido para compilação nativa em Android e iOS a partir de um único código base.
*   **Backend (API Node.js — Requisito do Projeto):**
    *   Servidor Node.js simples com Express, atuando como um **proxy** (ponte) entre o app Flutter e a API do Gemini.
    *   Função principal: receber a mensagem do usuário em JSON, repassar para a API do Gemini, e devolver a resposta ao Flutter.
    *   Motivo: proteger a chave de API do Gemini (ela fica segura no servidor, nunca exposta no app) e cumprir o requisito do ecossistema FitHub de consumir uma API Node.js.
*   **API de Inteligência Artificial:** **Google Gemini API** (via Google AI Studio).
    *   Modelo: Gemini Flash (rápido e leve para conversação).
    *   Camada gratuita disponível (sem custo adicional, já que o desenvolvedor possui conta Google assinada).
    *   A IA receberá um *system prompt* especializado em hidratação e saúde, garantindo respostas contextualizadas e precisas.
*   **Pacotes Flutter Principais:**
    *   `http` ou `dio` — Para requisições HTTP à API Node.js.
    *   `speech_to_text` — Para captura de áudio do microfone e conversão em texto (Speech-to-Text nativo do Flutter).
    *   `flutter_local_notifications` — Para disparar notificações push dos lembretes agendados.

## 3. Ambiente de Desenvolvimento (IDE)

*   **Antigravity:** O desenvolvimento será inteiramente conduzido dentro do ambiente inteligente Antigravity, utilizando IA agêntica para acelerar a estruturação do código Flutter, orquestrar a integração de APIs e automatizar tarefas do projeto.

## 4. Arquitetura do Projeto

Para garantir que o código seja limpo, manutenível e escalável:

*   **Padrão Arquitetural:** MVVM (Model-View-ViewModel).
*   **Gerência de Estado:** Provider ou Riverpod, garantindo que o chat e o dashboard sejam atualizados em tempo real quando a IA processar uma resposta.
*   **Divisão de Responsabilidades:**
    *   **View (Telas):** Chat, Dashboard, Configurações.
    *   **ViewModel (Lógica):** Processamento das mensagens, controle do contador de hidratação, agendamento de lembretes.
    *   **Services/Repositories:** Comunicação com a API Node.js, integração com o microfone (Speech-to-Text) e com o sistema de notificações locais.

## 5. Recurso Nativo do Aparelho

O aplicativo utilizará o seguinte recurso nativo do dispositivo:

*   **Microfone (Speech-to-Text):** O recurso nativo principal será o microfone do aparelho. Através do pacote `speech_to_text` do Flutter, o áudio captado pelo microfone é convertido em texto em tempo real, permitindo que o usuário converse com a IA por voz. Isso torna o app acessível e prático, eliminando a necessidade de digitação.

## 6. Banco de Dados e Infraestrutura

*   **Banco de Dados Local (no Celular):** O app utilizará um banco de dados interno no celular (`sqflite` ou `Hive`) para armazenar o histórico de mensagens do chat, os registros diários de consumo e os agendamentos de lembretes. Todos os dados ficam salvos localmente no aparelho do usuário.
*   **API Node.js (Proxy):** O servidor Node.js é leve e simples — sua única função é servir de ponte segura entre o Flutter e a API do Gemini. Pode ser executado localmente durante o desenvolvimento ou hospedado gratuitamente em plataformas como Render ou Railway.
