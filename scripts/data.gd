class_name MealData
extends RefCounted

## 全遊戲嘅靜態資料：食材、菜式、營養目標、天氣。
## 所有數值都係遊戲單位，唔係真實營養學數字，重點係取捨。

const DAYS := 7
const DAILY_BUDGET := 60

const STAT_KEYS: Array[String] = ["body", "vitc", "vitd", "fiber", "mood"]

const STATS := {
	"body": {"name": "體質", "target": 40.0, "color": "#F4775F", "note": "蛋白質"},
	"vitc": {"name": "維生素C", "target": 40.0, "color": "#EFA13C", "note": "蔬果"},
	"vitd": {"name": "維生素D", "target": 20.0, "color": "#6FA8D6", "note": "魚與陽光"},
	"fiber": {"name": "纖維", "target": 16.0, "color": "#77C2A0", "note": "腸胃"},
	"mood": {"name": "心情", "target": 20.0, "color": "#A78BC8", "note": "食得開心"},
}

const WEEKDAYS := ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]

const WEATHERS := {
	"sunny": {"name": "晴天", "line": "陽光幾好，出街買餸。"},
	"cloudy": {"name": "多雲", "line": "天色灰灰，煮飯最啱。"},
	"rainy": {"name": "落雨", "line": "落雨唔想出街，但飯總要食。"},
}

const QUALITY := {
	"perfect": {"name": "完美", "nutrition": 1.15, "mood": 1.15, "score": 2.0},
	"good": {"name": "唔錯", "nutrition": 1.0, "mood": 1.0, "score": 1.0},
	"burnt": {"name": "燶咗", "nutrition": 0.8, "mood": 0.7, "score": 0.0},
}

## 六種煮法：每道菜都有專屬煮法，每種煮法有唔同小遊戲。
## vessel 用嚟畫即時生成嘅菜式圖；action 係小遊戲提示。
const COOK_METHODS := {
	"pan_fry": {
		"name": "煎", "verb": "香煎", "vessel": "pan",
		"action": "按住煎香，放手起鍋",
		"goal": "綠色熟度帶",
		"line": "中火慢煎，兩面金黃。",
		"color": "#EF745E", "soft": "#FFE3DA",
	},
	"deep_fry": {
		"name": "炸", "verb": "香炸", "vessel": "fryer",
		"action": "三件輪流起鍋，撳準金黃圈",
		"goal": "每件嘅金黃圈",
		"line": "油夠熱，先會脆。",
		"color": "#E8A33C", "soft": "#FFF0CC",
	},
	"braise": {
		"name": "炆", "verb": "慢炆", "vessel": "clay_pot",
		"action": "拖住火候，保持慢火炆",
		"goal": "綠色慢火帶",
		"line": "細火慢炆，汁先會收得靚。",
		"color": "#B0764F", "soft": "#F3E6CE",
	},
	"stew": {
		"name": "燉", "verb": "慢燉", "vessel": "soup_pot",
		"action": "跟住 1 → 2 → 3 落料",
		"goal": "材料卡上嘅次序",
		"line": "一層一層落料，味道先會融。",
		"color": "#6FA8D6", "soft": "#E2EFF8",
	},
	"bake": {
		"name": "焗", "verb": "香焗", "vessel": "oven",
		"action": "拖旋鈕較到 180°C，再撳焗爐",
		"goal": "180°C 入爐",
		"line": "焗爐要預熱，芝士先會金黃。",
		"color": "#F0B94A", "soft": "#FFF0CC",
	},
	"steam": {
		"name": "蒸", "verb": "清蒸", "vessel": "steamer",
		"action": "蒸氣升到頂部綠帶時撳，連續三次",
		"goal": "頂部綠帶 ×3",
		"line": "水滾，蒸氣夠，鮮味先留得住。",
		"color": "#6FB794", "soft": "#DFF1E7",
	},
}
const COOK_METHOD_ORDER: Array[String] = ["pan_fry", "deep_fry", "braise", "stew", "bake", "steam"]

const INGREDIENTS := {
	"egg": {"name": "雞蛋", "price": 4, "cat": "protein"},
	"tomato": {"name": "番茄", "price": 5, "cat": "veg"},
	"greens": {"name": "菜心", "price": 5, "cat": "veg"},
	"tofu": {"name": "豆腐", "price": 6, "cat": "protein"},
	"rice": {"name": "白飯", "price": 3, "cat": "grain"},
	"bread": {"name": "麵包", "price": 4, "cat": "grain"},
	"milk": {"name": "牛奶", "price": 7, "cat": "dairy"},
	"oats": {"name": "燕麥", "price": 5, "cat": "grain"},
	"chicken": {"name": "雞胸", "price": 16, "cat": "protein"},
	"beef": {"name": "牛肉", "price": 18, "cat": "protein"},
	"salmon": {"name": "三文魚", "price": 24, "cat": "protein"},
	"banana": {"name": "香蕉", "price": 4, "cat": "fruit"},
	"yogurt": {"name": "乳酪", "price": 8, "cat": "dairy"},
	"potato": {"name": "薯仔", "price": 4, "cat": "veg"},
	"pumpkin": {"name": "南瓜", "price": 6, "cat": "veg"},
	"lettuce": {"name": "生菜", "price": 4, "cat": "veg"},
	"noodle": {"name": "即食麵", "price": 4, "cat": "grain"},
	"beans": {"name": "雜豆", "price": 6, "cat": "protein"},
	"cheese": {"name": "芝士", "price": 7, "cat": "dairy"},
	"chicken_leg": {"name": "雞腿", "price": 12, "cat": "protein"},
	"pork": {"name": "豬肉", "price": 14, "cat": "protein"},
	"shrimp": {"name": "蝦仁", "price": 18, "cat": "protein"},
	"broccoli": {"name": "西蘭花", "price": 7, "cat": "veg"},
	"onion": {"name": "洋蔥", "price": 4, "cat": "veg"},
	"mushroom": {"name": "蘑菇", "price": 6, "cat": "veg"},
	"corn": {"name": "粟米", "price": 5, "cat": "veg"},
	"udon": {"name": "烏冬", "price": 6, "cat": "grain"},
	"apple": {"name": "蘋果", "price": 4, "cat": "fruit"},
	"orange": {"name": "橙", "price": 5, "cat": "fruit"},
	"blueberry": {"name": "藍莓", "price": 12, "cat": "fruit"},
	"soy_milk": {"name": "豆漿", "price": 5, "cat": "dairy"},
	"sweet_potato": {"name": "番薯", "price": 4, "cat": "veg"},
}

## 自創食譜嘅營養由食材加總；現成食譜保留手調數值。
const INGREDIENT_NUTRITION := {
	"egg": {"protein": 6, "vitc": 0, "vitd": 4, "fiber": 0, "mood": 2, "kcal": 70},
	"tomato": {"protein": 1, "vitc": 14, "vitd": 0, "fiber": 2, "mood": 1, "kcal": 30},
	"greens": {"protein": 1, "vitc": 16, "vitd": 0, "fiber": 4, "mood": 1, "kcal": 40},
	"tofu": {"protein": 8, "vitc": 0, "vitd": 0, "fiber": 1, "mood": 1, "kcal": 120},
	"rice": {"protein": 4, "vitc": 0, "vitd": 0, "fiber": 1, "mood": 1, "kcal": 200},
	"bread": {"protein": 4, "vitc": 0, "vitd": 0, "fiber": 2, "mood": 1, "kcal": 140},
	"milk": {"protein": 6, "vitc": 0, "vitd": 10, "fiber": 0, "mood": 1, "kcal": 120},
	"oats": {"protein": 4, "vitc": 0, "vitd": 0, "fiber": 6, "mood": 1, "kcal": 150},
	"chicken": {"protein": 20, "vitc": 0, "vitd": 0, "fiber": 0, "mood": 1, "kcal": 200},
	"beef": {"protein": 18, "vitc": 0, "vitd": 0, "fiber": 0, "mood": 2, "kcal": 250},
	"salmon": {"protein": 16, "vitc": 0, "vitd": 20, "fiber": 0, "mood": 2, "kcal": 250},
	"banana": {"protein": 1, "vitc": 8, "vitd": 0, "fiber": 3, "mood": 2, "kcal": 90},
	"yogurt": {"protein": 4, "vitc": 2, "vitd": 6, "fiber": 0, "mood": 2, "kcal": 100},
	"potato": {"protein": 3, "vitc": 2, "vitd": 0, "fiber": 3, "mood": 1, "kcal": 130},
	"pumpkin": {"protein": 1, "vitc": 10, "vitd": 0, "fiber": 4, "mood": 1, "kcal": 60},
	"lettuce": {"protein": 1, "vitc": 8, "vitd": 0, "fiber": 3, "mood": 1, "kcal": 20},
	"noodle": {"protein": 5, "vitc": 0, "vitd": 0, "fiber": 1, "mood": 3, "kcal": 380},
	"beans": {"protein": 6, "vitc": 4, "vitd": 0, "fiber": 5, "mood": 1, "kcal": 120},
	"cheese": {"protein": 6, "vitc": 0, "vitd": 8, "fiber": 0, "mood": 2, "kcal": 110},
	"chicken_leg": {"protein": 14, "vitc": 0, "vitd": 2, "fiber": 0, "mood": 2, "kcal": 220},
	"pork": {"protein": 16, "vitc": 0, "vitd": 0, "fiber": 0, "mood": 2, "kcal": 240},
	"shrimp": {"protein": 18, "vitc": 0, "vitd": 2, "fiber": 0, "mood": 2, "kcal": 100},
	"broccoli": {"protein": 3, "vitc": 18, "vitd": 0, "fiber": 5, "mood": 1, "kcal": 50},
	"onion": {"protein": 1, "vitc": 6, "vitd": 0, "fiber": 2, "mood": 1, "kcal": 40},
	"mushroom": {"protein": 2, "vitc": 4, "vitd": 2, "fiber": 2, "mood": 1, "kcal": 30},
	"corn": {"protein": 2, "vitc": 8, "vitd": 0, "fiber": 3, "mood": 2, "kcal": 90},
	"udon": {"protein": 5, "vitc": 0, "vitd": 0, "fiber": 2, "mood": 2, "kcal": 300},
	"apple": {"protein": 0, "vitc": 10, "vitd": 0, "fiber": 3, "mood": 2, "kcal": 80},
	"orange": {"protein": 1, "vitc": 18, "vitd": 0, "fiber": 3, "mood": 2, "kcal": 70},
	"blueberry": {"protein": 0, "vitc": 12, "vitd": 0, "fiber": 4, "mood": 2, "kcal": 50},
	"soy_milk": {"protein": 3, "vitc": 0, "vitd": 4, "fiber": 1, "mood": 1, "kcal": 80},
	"sweet_potato": {"protein": 2, "vitc": 12, "vitd": 0, "fiber": 4, "mood": 2, "kcal": 120},
}

const CUSTOM_FORMS := ["plate", "bowl", "toast", "cup", "pan"]
const CUSTOM_FORM_NAMES := {"plate": "碟", "bowl": "碗", "toast": "多士", "cup": "杯", "pan": "鑊"}

static var custom_recipes: Array = []


## colors：碟上食物嘅三個主色，用嚟畫極簡食物圖。
const RECIPES := [
	{
		"id": "plain_rice", "name": "豉油白飯", "items": ["rice"],
		"protein": 4, "vitc": 0, "vitd": 0, "fiber": 1, "mood": 2, "kcal": 280,
		"method": "steam",
		"form": "bowl", "colors": ["#FFFDF6", "#F3E6CE", "#8B5E3C"], "tag": "捱住先",
	},
	{
		"id": "tomato_egg", "name": "番茄炒蛋", "items": ["tomato", "egg"],
		"protein": 6, "vitc": 14, "vitd": 4, "fiber": 3, "mood": 5, "kcal": 320,
		"method": "pan_fry",
		"form": "plate", "colors": ["#F26D5B", "#F7C948", "#7BAE6F"], "tag": "5 分鐘",
	},
	{
		"id": "beef_greens", "name": "菜心炒牛肉", "items": ["greens", "beef"],
		"protein": 18, "vitc": 16, "vitd": 2, "fiber": 7, "mood": 7, "kcal": 520,
		"method": "pan_fry",
		"form": "plate", "colors": ["#6FAE63", "#B0764F", "#F4E3C1"], "tag": "家常",
	},
	{
		"id": "salmon_rice", "name": "香煎三文魚飯", "items": ["salmon", "rice"],
		"protein": 20, "vitc": 2, "vitd": 24, "fiber": 2, "mood": 8, "kcal": 650,
		"method": "pan_fry",
		"form": "plate", "colors": ["#F0925F", "#FFF7E8", "#6FAE63"], "tag": "好日子",
	},
	{
		"id": "tofu_soup", "name": "豆腐青菜湯", "items": ["tofu", "greens"],
		"protein": 8, "vitc": 16, "vitd": 1, "fiber": 8, "mood": 4, "kcal": 230,
		"method": "stew",
		"form": "bowl", "colors": ["#F7F0DC", "#6FAE63", "#FFFDF6"], "tag": "清淡",
	},
	{
		"id": "egg_toast", "name": "太陽蛋多士", "items": ["egg", "bread"],
		"protein": 9, "vitc": 0, "vitd": 4, "fiber": 2, "mood": 7, "kcal": 340,
		"method": "pan_fry",
		"form": "toast", "colors": ["#E8C58C", "#FFFDF6", "#F7C948"], "tag": "早餐",
	},
	{
		"id": "milk_oats", "name": "牛奶燕麥", "items": ["milk", "oats"],
		"protein": 10, "vitc": 2, "vitd": 12, "fiber": 6, "mood": 5, "kcal": 380,
		"method": "stew",
		"form": "bowl", "colors": ["#F3E6CE", "#FFFDF6", "#D9BE93"], "tag": "早餐",
	},
	{
		"id": "banana_yogurt", "name": "香蕉乳酪杯", "items": ["banana", "yogurt"],
		"protein": 5, "vitc": 10, "vitd": 6, "fiber": 3, "mood": 9, "kcal": 290,
		"method": "bake",
		"form": "cup", "colors": ["#F5D96B", "#FFFDF6", "#EADFC4"], "tag": "5 分鐘",
	},
	{
		"id": "chicken_salad", "name": "雞胸沙律", "items": ["chicken", "lettuce", "tomato"],
		"protein": 26, "vitc": 24, "vitd": 1, "fiber": 9, "mood": 5, "kcal": 360,
		"method": "pan_fry",
		"form": "plate", "colors": ["#6FAE63", "#F26D5B", "#F2D6A2"], "tag": "高蛋白",
	},
	{
		"id": "noodle_egg", "name": "即食麵加蛋", "items": ["noodle", "egg"],
		"protein": 11, "vitc": 0, "vitd": 4, "fiber": 1, "mood": 10, "kcal": 520,
		"method": "stew",
		"form": "bowl", "colors": ["#F3D9A4", "#F7C948", "#F26D5B"], "tag": "懶人",
	},
	{
		"id": "pumpkin_soup", "name": "南瓜薯仔湯", "items": ["pumpkin", "potato", "milk"],
		"protein": 9, "vitc": 12, "vitd": 10, "fiber": 7, "mood": 6, "kcal": 380,
		"method": "stew",
		"form": "bowl", "colors": ["#F2A94B", "#F8D98B", "#FFFDF6"], "tag": "暖胃",
	},
	{
		"id": "bean_fried_rice", "name": "雜豆炒飯", "items": ["rice", "egg", "beans"],
		"protein": 14, "vitc": 4, "vitd": 2, "fiber": 7, "mood": 8, "kcal": 540,
		"method": "pan_fry",
		"form": "plate", "colors": ["#FFF7E8", "#7BAE6F", "#F7C948"], "tag": "飽肚",
	},
	{
		"id": "curry_chicken", "name": "咖喱薯仔雞", "items": ["potato", "chicken"],
		"protein": 23, "vitc": 2, "vitd": 1, "fiber": 4, "mood": 9, "kcal": 620,
		"method": "braise",
		"form": "plate", "colors": ["#E8B44A", "#C98A58", "#F4E3C1"], "tag": "惹味",
	},
	{
		"id": "banana_toast", "name": "香蕉多士", "items": ["banana", "bread"],
		"protein": 4, "vitc": 8, "vitd": 2, "fiber": 5, "mood": 8, "kcal": 300,
		"method": "bake",
		"form": "toast", "colors": ["#E8C58C", "#F5D96B", "#FFFDF6"], "tag": "早餐",
	},
	{
		"id": "cheese_potato", "name": "芝士焗薯", "items": ["potato", "cheese", "milk"],
		"protein": 12, "vitc": 4, "vitd": 14, "fiber": 4, "mood": 8, "kcal": 480,
		"method": "bake",
		"form": "pan", "colors": ["#F2C94C", "#F8E3A8", "#E8A85C"], "tag": "滿足",
	},
	{
		"id": "pork_onion_rice", "name": "洋蔥豬扒飯", "items": ["pork", "onion", "rice"],
		"protein": 22, "vitc": 6, "vitd": 1, "fiber": 5, "mood": 9, "kcal": 680,
		"method": "pan_fry",
		"form": "plate", "colors": ["#B0764F", "#F4E3C1", "#6FAE63"], "tag": "家常",
	},
	{
		"id": "shrimp_udon", "name": "蝦仁炒烏冬", "items": ["shrimp", "udon", "broccoli"],
		"protein": 20, "vitc": 10, "vitd": 2, "fiber": 7, "mood": 8, "kcal": 580,
		"method": "pan_fry",
		"form": "plate", "colors": ["#F0928A", "#F7E7C9", "#6FAE63"], "tag": "海鮮",
	},
	{
		"id": "mushroom_chicken_rice", "name": "蘑菇雞腿飯", "items": ["chicken_leg", "mushroom", "rice"],
		"protein": 24, "vitc": 4, "vitd": 2, "fiber": 4, "mood": 9, "kcal": 700,
		"method": "braise",
		"form": "plate", "colors": ["#B58A5C", "#FFF7E8", "#8B6B4A"], "tag": "飽肚",
	},
	{
		"id": "broccoli_shrimp", "name": "西蘭花炒蝦", "items": ["shrimp", "broccoli"],
		"protein": 18, "vitc": 18, "vitd": 2, "fiber": 7, "mood": 7, "kcal": 380,
		"method": "pan_fry",
		"form": "plate", "colors": ["#5E9E5A", "#F0928A", "#FFF7E8"], "tag": "高蛋白",
	},
	{
		"id": "soy_oats", "name": "豆漿燕麥", "items": ["soy_milk", "oats"],
		"protein": 8, "vitc": 2, "vitd": 6, "fiber": 6, "mood": 5, "kcal": 330,
		"method": "stew",
		"form": "bowl", "colors": ["#EFE2C8", "#F6E9CF", "#D9BE93"], "tag": "早餐",
	},
	{
		"id": "apple_yogurt", "name": "蘋果乳酪杯", "items": ["apple", "yogurt"],
		"protein": 5, "vitc": 10, "vitd": 6, "fiber": 5, "mood": 8, "kcal": 260,
		"method": "bake",
		"form": "cup", "colors": ["#E4574C", "#FFFDF6", "#EADFC4"], "tag": "5 分鐘",
	},
	{
		"id": "orange_chicken_salad", "name": "香橙雞沙律", "items": ["orange", "chicken", "lettuce"],
		"protein": 24, "vitc": 28, "vitd": 1, "fiber": 8, "mood": 7, "kcal": 390,
		"method": "pan_fry",
		"form": "plate", "colors": ["#F2A94B", "#6FAE63", "#F26D5B"], "tag": "清新",
	},
	{
		"id": "sweet_potato_soup", "name": "番薯牛奶湯", "items": ["sweet_potato", "milk"],
		"protein": 7, "vitc": 12, "vitd": 10, "fiber": 6, "mood": 6, "kcal": 340,
		"method": "stew",
		"form": "bowl", "colors": ["#E8A85C", "#F8D98B", "#FFFDF6"], "tag": "暖胃",
	},
	{
		"id": "onion_mushroom_soup", "name": "洋蔥蘑菇湯", "items": ["onion", "mushroom", "milk"],
		"protein": 6, "vitc": 6, "vitd": 10, "fiber": 5, "mood": 5, "kcal": 280,
		"method": "stew",
		"form": "bowl", "colors": ["#D9C3A0", "#B58A5C", "#FFFDF6"], "tag": "清淡",
	},
	{
		"id": "pork_udon", "name": "豬肉炒烏冬", "items": ["pork", "udon", "onion"],
		"protein": 20, "vitc": 6, "vitd": 1, "fiber": 4, "mood": 9, "kcal": 650,
		"method": "pan_fry",
		"form": "plate", "colors": ["#B0764F", "#F5E1B8", "#6FAE63"], "tag": "惹味",
	},
	{
		"id": "blueberry_toast", "name": "藍莓多士", "items": ["blueberry", "bread"],
		"protein": 4, "vitc": 6, "vitd": 2, "fiber": 5, "mood": 9, "kcal": 300,
		"method": "bake",
		"form": "toast", "colors": ["#E8C58C", "#6B5B95", "#FFFDF6"], "tag": "水果",
	},
	{
		"id": "corn_soup", "name": "粟米濃湯", "items": ["corn", "milk", "potato"],
		"protein": 8, "vitc": 8, "vitd": 10, "fiber": 5, "mood": 7, "kcal": 350,
		"method": "stew",
		"form": "bowl", "colors": ["#F2C94C", "#F8E3A8", "#FFFDF6"], "tag": "暖胃",
	},
	{
		"id": "fried_chicken_leg", "name": "香脆炸雞腿", "items": ["chicken_leg", "egg"],
		"protein": 20, "vitc": 0, "vitd": 6, "fiber": 1, "mood": 10, "kcal": 520,
		"method": "deep_fry",
		"form": "plate", "colors": ["#D99545", "#F7C948", "#FFFDF6"], "tag": "香脆",
	},
	{
		"id": "crispy_shrimp", "name": "黃金炸蝦", "items": ["shrimp", "corn"],
		"protein": 20, "vitc": 8, "vitd": 2, "fiber": 3, "mood": 9, "kcal": 430,
		"method": "deep_fry",
		"form": "plate", "colors": ["#F0B94A", "#F0928A", "#FFF7E8"], "tag": "香口",
	},
	{
		"id": "steamed_salmon", "name": "清蒸三文魚", "items": ["salmon", "greens"],
		"protein": 17, "vitc": 16, "vitd": 22, "fiber": 4, "mood": 7, "kcal": 330,
		"method": "steam",
		"form": "plate", "colors": ["#F0925F", "#6FAE63", "#FFF7E8"], "tag": "鮮味",
	},
	{
		"id": "steamed_tofu_egg", "name": "滑蛋蒸豆腐", "items": ["egg", "tofu"],
		"protein": 14, "vitc": 0, "vitd": 4, "fiber": 1, "mood": 7, "kcal": 240,
		"method": "steam",
		"form": "bowl", "colors": ["#F7E7A8", "#FFFDF6", "#F2D6A2"], "tag": "嫩滑",
	},
	{
		"id": "braised_pork", "name": "洋蔥炆豬肉", "items": ["pork", "onion", "rice"],
		"protein": 22, "vitc": 6, "vitd": 1, "fiber": 4, "mood": 9, "kcal": 640,
		"method": "braise",
		"form": "bowl", "colors": ["#B0764F", "#E8B44A", "#FFF7E8"], "tag": "惹味",
	},
]

## 每餐可以煮咩：全部菜式都可以，冇分早晚，等玩家自己配。
const MEAL_NAMES := ["早餐", "午餐", "晚餐"]
const MEAL_ICONS := ["朝", "晝", "夜"]


static func recipe(recipe_id: String) -> Dictionary:
	for item in RECIPES:
		if item.id == recipe_id:
			return item
	for item in custom_recipes:
		if item.id == recipe_id:
			return item
	return {}


static func all_recipes() -> Array:
	return RECIPES + custom_recipes


## 揀菜清單唔會顯示「自由創作」嘅即時菜式；佢哋只存在於當前嗰一局。
static func visible_recipes() -> Array:
	var result: Array = RECIPES.duplicate()
	for item in custom_recipes:
		if not bool(item.get("ephemeral", false)):
			result.append(item)
	return result


static func purge_ephemeral() -> void:
	for i in range(custom_recipes.size() - 1, -1, -1):
		if bool(custom_recipes[i].get("ephemeral", false)):
			custom_recipes.remove_at(i)


static func method_info(method_id: String) -> Dictionary:
	return COOK_METHODS.get(method_id, COOK_METHODS["pan_fry"])


static func method_name(method_id: String) -> String:
	return str(method_info(method_id).name)


static func method_of(recipe_data: Dictionary) -> String:
	var raw := str(recipe_data.get("method", ""))
	if COOK_METHODS.has(raw):
		return raw
	return suggest_method(recipe_data.get("items", []))


static func method_form(method_id: String) -> String:
	match method_id:
		"pan_fry":
			return "pan"
		"braise", "stew":
			return "bowl"
		"bake":
			return "pan"
		_:
			return "plate"


## 舊存檔／朋友分享碼冇 method 時，用材料估一個合理煮法。
static func suggest_method(items: Array) -> String:
	var has := {}
	for item_id in items:
		has[str(item_id)] = true
	if has.has("bread") or has.has("cheese") or has.has("blueberry") or has.has("banana"):
		return "bake"
	if has.has("salmon"):
		return "steam"
	if has.has("rice") or has.has("noodle") or has.has("udon"):
		if has.has("pork") or has.has("chicken") or has.has("chicken_leg") or has.has("beef"):
			return "braise"
		return "stew"
	if has.has("egg") or has.has("tofu"):
		return "steam"
	if has.has("pork") or has.has("chicken") or has.has("chicken_leg") or has.has("beef") or has.has("shrimp"):
		return "pan_fry"
	return "stew"


static func register_custom(recipe_data: Dictionary) -> void:
	var new_id := str(recipe_data.get("id", ""))
	if new_id.is_empty():
		return
	for i in range(custom_recipes.size()):
		if custom_recipes[i].id == new_id:
			custom_recipes[i] = recipe_data
			return
	custom_recipes.append(recipe_data)


static func ingredient_nutrition(item_id: String) -> Dictionary:
	return INGREDIENT_NUTRITION.get(item_id, {"protein": 0, "vitc": 0, "vitd": 0, "fiber": 0, "mood": 0, "kcal": 0})


static func custom_colors(items: Array) -> Array:
	var colors: Array = []
	for item_id in items:
		var hex := ingredient_color(item_id).to_html(false)
		if not hex.begins_with("#"):
			hex = "#" + hex
		colors.append(hex)
	while colors.size() < 3:
		colors.append(["#F7E7C9", "#FFF7E8", "#F3E6CE"][colors.size() % 3])
	return colors.slice(0, 3)


static func build_custom_recipe(recipe_id: String, recipe_name: String, items: Array, form: String, colors: Array, method: String = "") -> Dictionary:
	var totals := {"protein": 0, "vitc": 0, "vitd": 0, "fiber": 0, "mood": 0, "kcal": 0}
	for item_id in items:
		var nutrition := ingredient_nutrition(item_id)
		for key in totals:
			totals[key] += int(nutrition.get(key, 0))
	var resolved_method := method if COOK_METHODS.has(method) else suggest_method(items)
	return {
		"id": recipe_id,
		"name": recipe_name,
		"items": items.duplicate(),
		"protein": totals.protein,
		"vitc": totals.vitc,
		"vitd": totals.vitd,
		"fiber": totals.fiber,
		"mood": totals.mood + 2,
		"kcal": totals.kcal,
		"method": resolved_method,
		"form": form if form in CUSTOM_FORMS else method_form(resolved_method),
		"colors": custom_colors(items) if colors.is_empty() else colors,
		"tag": "自家製",
		"custom": true,
	}



static func stat_name(key: String) -> String:
	return STATS[key].name


static func stat_color(key: String) -> Color:
	return Color(STATS[key].color)


static func points(recipe_data: Dictionary) -> Dictionary:
	return {
		"body": float(recipe_data.get("protein", 0)),
		"vitc": float(recipe_data.get("vitc", 0)),
		"vitd": float(recipe_data.get("vitd", 0)),
		"fiber": float(recipe_data.get("fiber", 0)),
		"mood": float(recipe_data.get("mood", 0)),
	}


static func ingredient_price(item_id: String, price_mods: Dictionary) -> int:
	var base: float = float(INGREDIENTS[item_id].price)
	return int(round(base * float(price_mods.get(item_id, 1.0))))


static func recipe_price(recipe_data: Dictionary, price_mods: Dictionary) -> int:
	var total := 0
	for item in recipe_data.get("items", []):
		total += ingredient_price(item, price_mods)
	return total


static func ingredient_color(item_id: String) -> Color:
	var cat := str(INGREDIENTS.get(item_id, {}).get("cat", "veg"))
	match cat:
		"protein":
			return Color("#EF745E")
		"grain":
			return Color("#D9A93C")
		"dairy":
			return Color("#6FA8D6")
		"fruit":
			return Color("#A78BC8")
		_:
			return Color("#6FB794")


static func ingredient_soft_color(item_id: String) -> Color:
	var cat := str(INGREDIENTS.get(item_id, {}).get("cat", "veg"))
	match cat:
		"protein":
			return Color("#FFE3DA")
		"grain":
			return Color("#FFF0CC")
		"dairy":
			return Color("#E2EFF8")
		"fruit":
			return Color("#EEE7F6")
		_:
			return Color("#DFF1E7")


static func ingredient_initial(item_id: String) -> String:
	var name := str(INGREDIENTS.get(item_id, {}).get("name", "？"))
	return name.substr(0, 1)


static func ingredient_names(items: Array) -> String:
	var names: Array[String] = []
	for item in items:
		if INGREDIENTS.has(item):
			names.append(INGREDIENTS[item].name)
	return "・".join(names)


static func sale_items(recipe_data: Dictionary, sale_ids: Array) -> Array:
	var found: Array = []
	for item in recipe_data.get("items", []):
		if sale_ids.has(item):
			found.append(item)
	return found


static func item_names(recipe_data: Dictionary) -> String:
	var names: Array[String] = []
	for item in recipe_data.get("items", []):
		names.append(INGREDIENTS[item].name)
	return "・".join(names)


static func quality(quality_id: String) -> Dictionary:
	return QUALITY.get(quality_id, QUALITY["good"])


static func weekday(day: int) -> String:
	return WEEKDAYS[clampi(day - 1, 0, WEEKDAYS.size() - 1)]
