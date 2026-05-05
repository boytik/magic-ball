# Stellara backend

Cloudflare Worker, проксирующий запросы из iOS-приложения в LLM-провайдера.
По умолчанию используем **Groq** (бесплатно, без кредитки). При желании
переключается на Anthropic правкой `[vars] LLM_PROVIDER` в `wrangler.toml`.

## Деплой за 5 минут (Groq)

```bash
# 1. Wrangler (один раз глобально):
npm install -g wrangler

# 2. Логин в Cloudflare (откроется браузер):
wrangler login

# 3. Локальные зависимости:
cd backend
npm install

# 4. Создать KV для rate-limit'а:
wrangler kv namespace create RATE_LIMIT
# (для wrangler ≤ v3 было `wrangler kv:namespace create RATE_LIMIT`)
# скопируй id из вывода → вставь в wrangler.toml вместо REPLACE_WITH_KV_ID

# 5. Получить Groq API key:
#    → https://console.groq.com → залогинься → API Keys → Create
#    Бесплатно, без кредитки. Скопируй ключ (выглядит как gsk_...).

# 6. Положить ключ в секреты Worker'a:
wrangler secret put GROQ_API_KEY

# 7. Деплой:
npm run deploy
```

После деплоя получишь URL вида `https://stellara-oracle.<your-name>.workers.dev`.
Этот URL подставляется в iOS в `Stellara/Models/Config.swift`.

## Тест из терминала

```bash
curl -X POST https://stellara-oracle.<...>.workers.dev/predict \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: 11111111-1111-1111-1111-111111111111" \
  -d '{"question":"Поеду ли я завтра в город?","persona":"madame_lou"}'
```

Ожидаемый ответ:
```json
{ "answer": "Поедешь, дитя моё, и зонт возьми — дождь будет.",
  "persona": "madame_lou", "usedToday": 1, "dailyLimit": 3 }
```

## Переключение на Anthropic

```bash
# 1. В wrangler.toml поменять [vars] LLM_PROVIDER = "anthropic"
# 2. Положить Anthropic-ключ в секреты:
wrangler secret put ANTHROPIC_KEY
#    вставишь sk-ant-... из console.anthropic.com
# 3. Передеплоить:
npm run deploy
```

В `console.anthropic.com → Settings → Limits` обязательно поставь
**Monthly spend limit на $5–10** — защитит от случайного абуза.

## Какие модели Groq доступны

В `wrangler.toml` — `[vars] GROQ_MODEL`. Варианты:

- `llama-3.3-70b-versatile` (default) — лучшее качество ответов.
- `llama-3.1-8b-instant` — самая быстрая, простые ответы.
- `mixtral-8x7b-32768` — длинный контекст, хороший мультиязык.

Полный список и rate-лимиты — на console.groq.com → Models.

## Логи и отладка

```bash
wrangler tail   # стримит логи Worker'а в реальном времени
```

Если `/predict` отвечает 502 — обычно это `GROQ_API_KEY is not set`
(забыли `wrangler secret put`) или Groq вернул 4xx (видно в `wrangler tail`).
