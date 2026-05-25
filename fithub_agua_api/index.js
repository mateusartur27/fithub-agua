const express = require('express');
const cors = require('cors');
require('dotenv').config();
const { GoogleGenerativeAI } = require('@google/generative-ai');

const app = express();
app.use(cors());
app.use(express.json());

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const systemInstruction = `Você é o assistente virtual inteligente do app "FitHub Água". 
Sua missão principal é ajudar o usuário a manter-se hidratado. 
Você deve sempre retornar um JSON estrito, sem formatação markdown em volta, com a seguinte estrutura:
{
  "message": "Sua resposta natural conversacional aqui.",
  "action_payload": {
    "action": "none" | "add_water" | "set_reminder",
    "amount_ml": 0,
    "interval_minutes": 0
  }
}
Responda de forma curta, prestativa e amigável. Identifique quando o usuário registrar consumo de água ou pedir lembretes.`;

app.post('/api/chat', async (req, res) => {
  try {
    const { history, message } = req.body;

    // Instancia o modelo configurado para retornar JSON garantido
    const model = genAI.getGenerativeModel({ 
      model: "gemini-1.5-flash",
      systemInstruction: systemInstruction,
      generationConfig: { responseMimeType: "application/json" }
    });

    const chat = model.startChat({
      history: history || [],
    });

    const result = await chat.sendMessage(message);
    const responseText = result.response.text();
    
    // Parse JSON seguro
    const data = JSON.parse(responseText);
    res.json(data);

  } catch (error) {
    console.error("Erro no processamento do chat:", error);
    res.status(500).json({ error: "Erro interno no servidor da IA." });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 FitHub Água API (Proxy Gemini) rodando na porta ${PORT}`);
});
