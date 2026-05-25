import { GoogleGenerativeAI } from "@google/generative-ai";

const systemInstruction = `Você é o parceiro de saúde e hidratação do ecossistema "FitHub Água". 
Sua personalidade é amigável, acolhedora e imersiva. NUNCA diga que você é uma "IA", um "robô" ou mencione termos técnicos (como JSON, Node, Servidor). Aja como um humano especialista em nutrição.
Seu primeiro objetivo (caso ainda não saiba) é descobrir o peso do usuário de forma gentil ("Qual o seu peso para eu calcular sua meta ideal?"). 
A regra médica é: Peso (kg) * 35 = Meta de água em ml.
Sempre que descobrir a meta, ou quando o usuário beber água, ou pedir lembrete, você deve refletir isso no JSON.
Você deve SEMPRE retornar APENAS um JSON estrito, sem formatação markdown, com a estrutura:
{
  "message": "Sua resposta natural conversacional aqui.",
  "action_payload": {
    "action": "none" | "add_water" | "set_reminder" | "set_goal",
    "amount_ml": 0, // preencha se for add_water ou set_goal
    "interval_minutes": 0
  }
}`;

export default {
  async fetch(request, env, ctx) {
    // Lidando com CORS (para o Flutter Web/Mobile poder chamar a API)
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    if (request.method !== "POST") {
      return new Response("Apenas POST suportado", { status: 405 });
    }

    try {
      const body = await request.json();
      const { history, message } = body;

      // Usando a chave que estará segura no Cloudflare (via wrangler secret)
      const genAI = new GoogleGenerativeAI(env.GEMINI_API_KEY);
      
      const model = genAI.getGenerativeModel({ 
        model: "gemini-2.5-flash",
        systemInstruction: systemInstruction,
        generationConfig: { responseMimeType: "application/json" }
      });

      // O Gemini exige que o histórico SEMPRE comece com role 'user'.
      // A mensagem inicial do app é do 'model', então filtramos até o primeiro 'user'.
      let safeHistory = (history || []);
      const firstUserIndex = safeHistory.findIndex(m => m.role === "user");
      if (firstUserIndex > 0) {
        safeHistory = safeHistory.slice(firstUserIndex);
      } else if (firstUserIndex === -1) {
        safeHistory = [];
      }

      const chat = model.startChat({
        history: safeHistory,
      });

      const result = await chat.sendMessage(message);
      const responseText = result.response.text();
      
      return new Response(responseText, {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        }
      });
    } catch (error) {
      console.error(error);
      return new Response(JSON.stringify({ error: "Erro interno no servidor da IA." }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        }
      });
    }
  },
};
