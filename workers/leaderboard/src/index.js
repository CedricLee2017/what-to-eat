/**
 * 隞憌憟踝???瘥???璁?API
 *
 * GET  /api/leaderboard?date=YYYYMMDD&limit=10
 * POST /api/leaderboard
 *
 * ?芣???交??啜?蝮整??蝵格??亙?舀?鈭支?甈∴?
 * ??曹撩???stats ?閮?嚗蒂???蝭??? */

const MAX_BODY_BYTES = 4096;
const MAX_FAVOURITE = 40;
const DEFAULT_LIMIT = 10;
const RATE_WINDOW_MS = 60_000;
const buckets = new Map();

export default {
	async fetch(request, env) {
		const url = new URL(request.url);
		const cors = corsHeaders(request, env);
		try {
			if (url.pathname !== "/api/leaderboard" && url.pathname !== "/api/leaderboard/" &&
				url.pathname !== "/api/recipes" && url.pathname !== "/api/recipes/" &&
				url.pathname !== "/api/rewards" && !/^\/api\/recipes\/[A-Za-z0-9_-]{8,64}\/like$/.test(url.pathname)) {
				return json({ ok: false, error: "not_found" }, 404, cors);
			}
			if (request.method === "OPTIONS") {
				return new Response(null, { status: 204, headers: cors });
			}
			if (url.pathname === "/api/recipes" || url.pathname === "/api/recipes/") {
				if (request.method === "GET") return await handleRecipesGet(request, env, url, cors);
				if (request.method === "POST") return await handleRecipePost(request, env, cors);
				return json({ ok: false, error: "method_not_allowed" }, 405, cors);
			}
			if (url.pathname === "/api/rewards") {
				if (request.method === "GET") return await handleRewards(request, env, url, cors);
				return json({ ok: false, error: "method_not_allowed" }, 405, cors);
			}
			const likeMatch = url.pathname.match(/^\/api\/recipes\/([A-Za-z0-9_-]{8,64})\/like$/);
			if (likeMatch) {
				if (request.method === "POST") return await handleRecipeLike(request, env, cors, likeMatch[1]);
				return json({ ok: false, error: "method_not_allowed" }, 405, cors);
			}
			if (request.method === "GET") {
				return await handleGet(request, env, url, cors);
			}
			if (request.method === "POST") {
				return await handlePost(request, env, cors);
			}
			return json({ ok: false, error: "method_not_allowed" }, 405, cors);
		} catch (error) {
			console.error("leaderboard error", error);
			return json({ ok: false, error: "server_error" }, 500, cors);
		}
	},
};

async function handleGet(request, env, url, cors) {
	const ip = clientIp(request);
	if (!rateLimit(`${ip}:get`, 60)) {
		return json({ ok: false, error: "rate_limited" }, 429, cors);
	}
	const date = url.searchParams.get("date") || todayKey();
	if (!/^\d{8}$/.test(date)) {
		return json({ ok: false, error: "bad_date" }, 400, cors);
	}
	const limit = Math.max(1, Math.min(50, Number(url.searchParams.get("limit") || DEFAULT_LIMIT) || DEFAULT_LIMIT));

	const rows = await env.DB.prepare(
		`SELECT average, grade, savings, favourite, distinct_count, perfect, burnt
		 FROM scores
		 WHERE date_key = ?
		 ORDER BY average DESC, savings DESC, created_at ASC
		 LIMIT ?`,
	)
		.bind(date, limit)
		.all();

	const totalRow = await env.DB.prepare("SELECT COUNT(*) AS total FROM scores WHERE date_key = ?")
		.bind(date)
		.first();

	const entries = (rows.results || []).map((row, index) => ({
		rank: index + 1,
		average: Number(row.average),
		grade: String(row.grade),
		savings: Number(row.savings),
		favourite: String(row.favourite || ""),
		distinct: Number(row.distinct_count),
		perfect: Number(row.perfect),
		burnt: Number(row.burnt),
	}));

	return json(
		{
			ok: true,
			date,
			total: Number(totalRow?.total || 0),
			entries,
		},
		200,
		cors,
	);
}

async function handlePost(request, env, cors) {
	const ip = clientIp(request);
	if (!rateLimit(`${ip}:post`, 6)) {
		return json({ ok: false, error: "rate_limited" }, 429, cors);
	}
	if (!env.DB) {
		return json({ ok: false, error: "database_not_configured" }, 500, cors);
	}

	const declaredLength = Number(request.headers.get("content-length") || 0);
	if (declaredLength > MAX_BODY_BYTES) {
		return json({ ok: false, error: "body_too_large" }, 413, cors);
	}
	const text = await request.text();
	if (text.length > MAX_BODY_BYTES) {
		return json({ ok: false, error: "body_too_large" }, 413, cors);
	}

	let body;
	try {
		body = JSON.parse(text);
	} catch {
		return json({ ok: false, error: "bad_json" }, 400, cors);
	}
	if (typeof body !== "object" || body === null || Array.isArray(body)) {
		return json({ ok: false, error: "bad_json" }, 400, cors);
	}

	const deviceId = String(body.device_id || "");
	if (!/^[A-Za-z0-9_-]{16,64}$/.test(deviceId)) {
		return json({ ok: false, error: "bad_device" }, 400, cors);
	}

	const date = String(body.date_key || "");
	const age = dateAgeDays(date);
	if (!/^\d{8}$/.test(date) || age < 0 || age > 14) {
		return json({ ok: false, error: "challenge_expired" }, 400, cors);
	}

	const stats = body.stats;
	if (typeof stats !== "object" || stats === null || Array.isArray(stats)) {
		return json({ ok: false, error: "bad_stats" }, 400, cors);
	}
	const statKeys = ["body", "vitc", "vitd", "fiber", "mood"];
	const values = [];
	for (const key of statKeys) {
		const value = Number(stats[key]);
		if (!Number.isFinite(value) || value < 0 || value > 100) {
			return json({ ok: false, error: "bad_stats" }, 400, cors);
		}
		values.push(value);
	}
	const average = Math.round((values.reduce((sum, value) => sum + value, 0) / values.length) * 10) / 10;
	const grade = gradeFor(average);

	const savings = Math.trunc(Number(body.savings));
	const distinct = Math.trunc(Number(body.distinct));
	const perfect = Math.trunc(Number(body.perfect));
	const burnt = Math.trunc(Number(body.burnt));
	if (
		!Number.isFinite(savings) || savings < 0 || savings > 600 ||
		!Number.isFinite(distinct) || distinct < 0 || distinct > 27 ||
		!Number.isFinite(perfect) || perfect < 0 || perfect > 21 ||
		!Number.isFinite(burnt) || burnt < 0 || burnt > 21
	) {
		return json({ ok: false, error: "bad_score" }, 400, cors);
	}

	let favourite = String(body.favourite || "").replace(/[\u0000-\u001f\u007f]/g, "").slice(0, MAX_FAVOURITE);

	const createdAt = Date.now();
	const result = await env.DB.prepare(
		`INSERT INTO scores
		 (device_id, date_key, average, grade, savings, favourite, distinct_count, perfect, burnt, stats_json, created_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		 ON CONFLICT(device_id, date_key) DO NOTHING`,
	)
		.bind(
			deviceId,
			date,
			average,
			grade,
			savings,
			favourite,
			distinct,
			perfect,
			burnt,
			JSON.stringify({ body: values[0], vitc: values[1], vitd: values[2], fiber: values[3], mood: values[4] }),
			createdAt,
		)
		.run();

	if (!result.meta || Number(result.meta.changes) === 0) {
		return json({ ok: false, error: "already_submitted" }, 409, cors);
	}

	const better = await env.DB.prepare(
		`SELECT COUNT(*) AS n FROM scores
		 WHERE date_key = ?
		   AND (average > ? OR (average = ? AND savings > ?) OR (average = ? AND savings = ? AND created_at < ?))`,
	)
		.bind(date, average, average, savings, average, savings, createdAt)
		.first();
	const total = await env.DB.prepare("SELECT COUNT(*) AS total FROM scores WHERE date_key = ?")
		.bind(date)
		.first();

	return json(
		{
			ok: true,
			rank: Number(better?.n || 0) + 1,
			total: Number(total?.total || 0),
			average,
			grade,
		},
		200,
		cors,
	);
}

function gradeFor(average) {
	if (average >= 82) return "S";
	if (average >= 72) return "A";
	if (average >= 62) return "B";
	if (average >= 52) return "C";
	return "D";
}

const ALLOWED_ITEMS = new Set([
	"egg", "tomato", "greens", "tofu", "rice", "bread", "milk", "oats",
	"chicken", "beef", "salmon", "banana", "yogurt", "potato", "pumpkin",
	"lettuce", "noodle", "beans", "cheese", "chicken_leg", "pork", "shrimp",
	"broccoli", "onion", "mushroom", "corn", "udon", "apple", "orange",
	"blueberry", "soy_milk", "sweet_potato",
]);
const ALLOWED_FORMS = new Set(["plate", "bowl", "toast", "cup", "pan"]);
const ALLOWED_METHODS = new Set(["pan_fry", "deep_fry", "braise", "stew", "bake", "steam"]);

async function readJsonBody(request) {
	const declaredLength = Number(request.headers.get("content-length") || 0);
	if (declaredLength > MAX_BODY_BYTES) return { error: "body_too_large" };
	const text = await request.text();
	if (text.length > MAX_BODY_BYTES) return { error: "body_too_large" };
	try {
		const body = JSON.parse(text);
		if (typeof body !== "object" || body === null || Array.isArray(body)) return { error: "bad_json" };
		return { body };
	} catch {
		return { error: "bad_json" };
	}
}

function cleanText(value) {
	return String(value || "").replace(/[\u0000-\u001f\u007f]/g, "").trim();
}

async function handleRecipesGet(request, env, url, cors) {
	const ip = clientIp(request);
	if (!rateLimit(`${ip}:recipes:get`, 60)) {
		return json({ ok: false, error: "rate_limited" }, 429, cors);
	}
	const limit = Math.max(1, Math.min(30, Number(url.searchParams.get("limit") || 20) || 20));
	const rows = await env.DB.prepare(
		`SELECT id, name, items_json, form, method, colors_json, like_count, created_at
		 FROM recipes ORDER BY like_count DESC, created_at DESC LIMIT ?`,
	).bind(limit).all();
	const recipes = [];
	for (const row of rows.results || []) {
		let items;
		let colors;
		try {
			items = JSON.parse(row.items_json);
			colors = JSON.parse(row.colors_json);
		} catch {
			continue;
		}
		if (!Array.isArray(items) || !Array.isArray(colors)) continue;
		recipes.push({
			id: String(row.id),
			name: String(row.name),
			items,
			form: String(row.form),
			method: ALLOWED_METHODS.has(String(row.method)) ? String(row.method) : "pan_fry",
			colors,
			like_count: Number(row.like_count),
		});
	}
	return json({ ok: true, recipes }, 200, cors);
}

async function handleRecipePost(request, env, cors) {
	const ip = clientIp(request);
	if (!rateLimit(`${ip}:recipes:post`, 3)) {
		return json({ ok: false, error: "rate_limited" }, 429, cors);
	}
	const parsed = await readJsonBody(request);
	if (parsed.error) return json({ ok: false, error: parsed.error }, parsed.error === "body_too_large" ? 413 : 400, cors);
	const body = parsed.body;
	const deviceId = String(body.device_id || "");
	if (!/^[A-Za-z0-9_-]{16,64}$/.test(deviceId)) {
		return json({ ok: false, error: "bad_device" }, 400, cors);
	}
	const name = cleanText(body.name).slice(0, 24);
	if (name.length < 1) return json({ ok: false, error: "bad_name" }, 400, cors);
	const rawItems = Array.isArray(body.items) ? body.items : [];
	const items = [];
	for (const item of rawItems) {
		const text = String(item);
		if (!ALLOWED_ITEMS.has(text)) return json({ ok: false, error: "bad_items" }, 400, cors);
		if (!items.includes(text)) items.push(text);
	}
	if (items.length < 1 || items.length > 3) {
		return json({ ok: false, error: "bad_items" }, 400, cors);
	}
	const form = String(body.form || "plate");
	if (!ALLOWED_FORMS.has(form)) return json({ ok: false, error: "bad_form" }, 400, cors);
	const method = String(body.method || "pan_fry");
	if (!ALLOWED_METHODS.has(method)) return json({ ok: false, error: "bad_method" }, 400, cors);
	const rawColors = Array.isArray(body.colors) ? body.colors : [];
	const colors = rawColors.slice(0, 3).map((color) => String(color));
	if (colors.length !== 3 || colors.some((color) => !/^#[0-9A-Fa-f]{6}$/.test(color))) {
		return json({ ok: false, error: "bad_colors" }, 400, cors);
	}
	const id = crypto.randomUUID().replace(/-/g, "").slice(0, 16);
	await env.DB.prepare(
		`INSERT INTO recipes (id, creator_device, name, items_json, form, method, colors_json, like_count, created_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)`,
	).bind(id, deviceId, name, JSON.stringify(items), form, method, JSON.stringify(colors), Date.now()).run();
	return json({ ok: true, id }, 200, cors);
}

async function handleRecipeLike(request, env, cors, recipeId) {
	const ip = clientIp(request);
	if (!rateLimit(`${ip}:recipes:like`, 15)) {
		return json({ ok: false, error: "rate_limited" }, 429, cors);
	}
	const parsed = await readJsonBody(request);
	if (parsed.error) return json({ ok: false, error: parsed.error }, parsed.error === "body_too_large" ? 413 : 400, cors);
	const deviceId = String(parsed.body.device_id || "");
	if (!/^[A-Za-z0-9_-]{16,64}$/.test(deviceId)) {
		return json({ ok: false, error: "bad_device" }, 400, cors);
	}
	const recipe = await env.DB.prepare("SELECT creator_device, like_count FROM recipes WHERE id = ?")
		.bind(recipeId).first();
	if (!recipe) return json({ ok: false, error: "not_found" }, 404, cors);
	if (String(recipe.creator_device) === deviceId) {
		return json({ ok: false, error: "self_like" }, 403, cors);
	}
	const inserted = await env.DB.prepare(
		"INSERT INTO recipe_likes (recipe_id, device_id, created_at) VALUES (?, ?, ?) ON CONFLICT(recipe_id, device_id) DO NOTHING",
	).bind(recipeId, deviceId, Date.now()).run();
	if (inserted.meta && Number(inserted.meta.changes) > 0) {
		await env.DB.prepare("UPDATE recipes SET like_count = like_count + 1 WHERE id = ?")
			.bind(recipeId).run();
	}
	const updated = await env.DB.prepare("SELECT like_count FROM recipes WHERE id = ?")
		.bind(recipeId).first();
	return json({ ok: true, id: recipeId, like_count: Number(updated?.like_count || 0) }, 200, cors);
}

async function handleRewards(request, env, url, cors) {
	const ip = clientIp(request);
	if (!rateLimit(`${ip}:rewards`, 30)) {
		return json({ ok: false, error: "rate_limited" }, 429, cors);
	}
	const deviceId = String(url.searchParams.get("device_id") || "");
	if (!/^[A-Za-z0-9_-]{16,64}$/.test(deviceId)) {
		return json({ ok: false, error: "bad_device" }, 400, cors);
	}
	const row = await env.DB.prepare(
		"SELECT COALESCE(SUM(like_count), 0) AS likes FROM recipes WHERE creator_device = ?",
	).bind(deviceId).first();
	return json({ ok: true, likes: Number(row?.likes || 0) }, 200, cors);
}

function todayKey(offsetDays = 0) {
	const date = new Date(Date.now() + offsetDays * 86_400_000);
	return date.toISOString().slice(0, 10).replace(/-/g, "");
}

function dateAgeDays(dateKey) {
	if (!/^\d{8}$/.test(dateKey)) return -1;
	const year = Number(dateKey.slice(0, 4));
	const month = Number(dateKey.slice(4, 6));
	const day = Number(dateKey.slice(6, 8));
	const target = Date.UTC(year, month - 1, day);
	const now = new Date();
	const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
	return Math.floor((today - target) / 86_400_000);
}

function clientIp(request) {
	return request.headers.get("cf-connecting-ip") || "local";
}

function rateLimit(key, limit) {
	const now = Date.now();
	const bucket = buckets.get(key);
	if (!bucket || now - bucket.start > RATE_WINDOW_MS) {
		buckets.set(key, { start: now, count: 1 });
		trimBuckets(now);
		return true;
	}
	bucket.count += 1;
	return bucket.count <= limit;
}

function trimBuckets(now) {
	if (buckets.size < 5000) return;
	for (const [key, bucket] of buckets) {
		if (now - bucket.start > RATE_WINDOW_MS) buckets.delete(key);
	}
}

function corsHeaders(request, env) {
	const allowed = String(env.ALLOWED_ORIGIN || "*");
	const origin = request.headers.get("Origin") || "";
	let allowOrigin = "*";
	if (allowed !== "*") {
		const list = allowed.split(",").map((part) => part.trim()).filter(Boolean);
		allowOrigin = list.includes(origin) ? origin : (list[0] || "null");
	}
	return {
		"Access-Control-Allow-Origin": allowOrigin,
		"Access-Control-Allow-Methods": "GET, POST, OPTIONS",
		"Access-Control-Allow-Headers": "Content-Type, Accept",
		"Access-Control-Max-Age": "86400",
		"Vary": "Origin",
		"Cache-Control": "no-store",
	};
}

function json(data, status, cors) {
	return new Response(JSON.stringify(data), {
		status,
		headers: {
			...cors,
			"Content-Type": "application/json; charset=utf-8",
		},
	});
}
