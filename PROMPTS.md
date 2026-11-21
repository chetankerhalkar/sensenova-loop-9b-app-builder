# Prompts

These are the exact prompts the App Builder sends to llama.cpp. The buttons in the page fill them in for you; they are here so you can read, copy or change them.

## System prompt (sent with every build)

```text
You are a senior front-end engineer who builds polished, working web apps.
Rules:
- Reply with ONE complete HTML file and nothing else. Start with <!DOCTYPE html> and end with </html>.
- Put all CSS in one <style> tag and all JavaScript in one <script> tag at the end of <body>.
- No external files, CDNs, web fonts, images or network calls. Everything must work offline.
- Use modern vanilla JavaScript. Draw charts and games with <canvas> or inline SVG.
- Make it look professional: dark theme, clear spacing, rounded cards, smooth hover states, responsive layout.
- Wrap any localStorage use in try/catch (the app may run in a sandbox).
- Include realistic sample data so the app looks alive on first load.
- Check that every element id used in JavaScript exists in the HTML.
```

## Build 1: Everyday, PocketPilot expense tracker

```text
Build "PocketPilot", a personal expense tracker.
- Header with the app name and the current month.
- Form to add an expense: description, amount, category (Food, Rent, Travel, Shopping, Bills, Fun), date.
- Summary cards: total spent, monthly budget (editable, default $2,000), money left, and a progress bar that turns orange at 80% and red over 100%.
- A donut chart drawn on <canvas> showing spending by category, with a legend.
- A list of expenses, newest first, with a delete button and a search box.
- Start with 10 realistic sample expenses.
- Everything updates instantly when I add or delete an expense.
```

## Build 2: Enterprise, OpsPulse incident command center

```text
Build "OpsPulse", an IT incident command center dashboard for a support team.
- Top row of 4 KPI cards: open incidents, critical (P1), average time to resolve, SLA at risk.
- A table of 15 sample incidents: ID, title, service, priority (P1-P4 colored badges), status (New, Investigating, Resolved), owner, and a live SLA countdown timer that turns red under 10 minutes.
- Filters for priority, status and service, plus a search box.
- Click a row to open a side panel with details, a timeline of updates, and buttons: Assign to me, Escalate, Resolve.
- A bar chart on <canvas> showing open incidents by service.
- A "New incident" button that opens a form and adds the incident to the table.
- KPIs and the chart update when anything changes.
```

## Build 3: Game, Neon Breaker

```text
Build "Neon Breaker", a brick breaker game on <canvas>.
- Neon look: dark background, glowing paddle, ball and colorful bricks.
- Control the paddle with the mouse or the Left/Right arrow keys. Space to launch the ball.
- 6 rows of bricks; some need 2 hits (show cracks).
- Score, lives (3) and level shown at the top. Clear all bricks to go to the next level with a faster ball.
- Power-ups sometimes fall from broken bricks: wider paddle, multi-ball, slow ball.
- Particle burst when a brick breaks, and a short screen shake when a life is lost.
- Start screen, pause with P, and a Game Over screen with Restart.
```

## Build 4: Your own idea (template)

```text
Build "<APP NAME>", <one-line idea from the live chat>.
- Must-have feature 1:
- Must-have feature 2:
- Must-have feature 3:
- Start with realistic sample data so it looks alive.
```

## Improve prompts

Type one into **Improve the current app**, then click **Improve current app**. The first four are also one-click buttons.

- `Fix every bug you can find and make sure all buttons work.`
- `Make it look more premium: better spacing, subtle gradients, smooth animations.`
- `Make it fully mobile friendly.`
- `Add a dark/light theme toggle in the header.`
- `Make the ball 10% faster each level and add short sound effects with the Web Audio API.`
- `Add an "Export CSV" button for the table.`
- `Finish the file. Return the COMPLETE HTML.` (use this when a build stops halfway)

**Auto-fix errors** sends the browser's error messages back to the model for you, so you don't need to type anything.
