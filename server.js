const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');

const app = express();
const PORT = 3000;

// OpenAI API Key
const OPENAI_API_KEY = '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';

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('.'));

// API endpoint to generate excuses
app.post('/api/generate', async (req, res) => {
    try {
        const { language, systemPrompt, userPrompt } = req.body;

        const response = await fetch('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${OPENAI_API_KEY}`
            },
            body: JSON.stringify({
                model: 'gpt-4',
                messages: [
                    {
                        role: 'system',
                        content: systemPrompt
                    },
                    {
                        role: 'user',
                        content: userPrompt
                    }
                ],
                temperature: 0.8,
                max_tokens: 150
            })
        });

        if (!response.ok) {
            const errorData = await response.json();
            return res.status(response.status).json({ error: errorData });
        }

        const data = await response.json();
        res.json({ excuse: data.choices[0].message.content.trim() });
    } catch (error) {
        console.error('Error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
    console.log(`Open http://localhost:${PORT}/index.html in your browser`);
});
