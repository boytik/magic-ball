# Stellara backend

Cloudflare Worker, который проксирует запросы из iOS-приложения в Anthropic API.

## Деплой за 5 минут

```bash
# 1. Установить wrangler (один раз глобально):
npm install -g wrangler

# 2. Логин в Cloudflare (откроется браузер):
wrangler login

# 3. Установить локальные зависимости:
cd backend
npm install

# 4. Создать KV для rate-limit'а:
wrangler kv:namespace create RATE_LIMIT
# скопируй id из вывода → вставь в wrangler.toml вместо REPLACE_WITH_KV_ID

# 5. Положить ключ Anthropic в секреты:
wrangler secret put ANTHROPIC_KEY
# вставишь sk-ant-... из console.anthropic.com

# 6. Деплой:
npm run deploy
```

После деплоя получишь URL вида `https://stellara-oracle.<your-name>.workers.dev`.
Этот URL подставляется в iOS в `Config.swift`.

## Тест из терминала

```bash
curl -X POST https://stellara-oracle.<...>.workers.dev/predict \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: 11111111-1111-1111-1111-111111111111" \
  -d '{"question":"Поеду ли я завтра в город?","persona":"madame_lou"}'
```

Ожидаемый ответ:
```json
{ "answer": "Поедешь, дитя моё, и зонт возьми — дождь будет.", "persona": "madame_lou", "usedToday": 1, "dailyLimit": 30 }
```

## Spend limit на Anthropic

Обязательно зайди в `console.anthropic.com → Settings → Limits` и поставь
**Monthly spend limit на $5–10** на старте. Без этого случайный баг или абуз
может слить деньги.
