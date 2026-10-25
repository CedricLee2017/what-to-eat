export default {
	async fetch(request, env) {
		const url = new URL(request.url);

		// Godot 會請求 /index.wasm。原始 wasm 超過 Cloudflare 靜態資源 25 MiB 上限，
		// 所以實際儲存的是 gzip 版本；這裡即時解壓成原始 wasm 回傳，
		// 避免瀏覽器 / instantiateStreaming 對 Content-Encoding 的處理差異。
		if (url.pathname === "/index.wasm") {
			const assetUrl = new URL("/_wasm/index.wasm.gz", url);
			const asset = await env.ASSETS.fetch(new Request(assetUrl.toString(), request));
			if (!asset.ok) {
				return asset;
			}
			const headers = new Headers();
			headers.set("Content-Type", "application/wasm");
			headers.set("Cache-Control", "public, max-age=31536000, immutable");
			headers.set("Access-Control-Allow-Origin", "*");
			if (request.method === "HEAD") {
				return new Response(null, { status: 200, headers });
			}
			const decompressed = asset.body.pipeThrough(new DecompressionStream("gzip"));
			return new Response(decompressed, { status: 200, headers });
		}

		return env.ASSETS.fetch(request);
	},
};
