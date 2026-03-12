import asyncio
import os
import logging
from datetime import datetime

from aiogram import Bot, Dispatcher, types, F
from aiogram.filters import Command
from aiogram.fsm.state import State, StatesGroup
from aiogram.fsm.context import FSMContext
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton, ReplyKeyboardMarkup, KeyboardButton, ReplyKeyboardRemove
from starlette.applications import Starlette
from starlette.responses import Response, PlainTextResponse
from starlette.requests import Request
from starlette.routing import Route
import uvicorn

# Log sozlamalari
logging.basicConfig(level=logging.INFO)

# ================== SOZLAMALAR ==================
TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "8794709341:AAGr6QoDr_WhyvG_mN_X1n_KXxIOsQZMxH4")
ADMIN_ID = int(os.environ.get("ADMIN_ID", "8167897562"))

# Render URL (avtomatik beriladi)
RENDER_URL = os.environ.get("RENDER_EXTERNAL_URL")
PORT = int(os.getenv("PORT", 8000))

# ================== FATVO 2026 ==================
ZAKOT_NISOB = 100_000_000
ZAKOT_FOIZ = 0.025

FITR = {
    "Bug‘doy (2 kg)": 10_000,
    "Un (2 kg)": 12_000,
    "Arpa (4 kg)": 20_000,
    "Mayiz (2 kg)": 110_000,
    "Xurmo (4 kg)": 200_000,
}

FIDYA_BIR_KUN = 10_000

# ================== BOT ==================
bot = Bot(token=TOKEN)
dp = Dispatcher()

# ================== STATES ==================
class StartState(StatesGroup):
    ism = State()

class ZakotState(StatesGroup):
    pul = State()
    savdo = State()
    oltin = State()
    kumush = State()
    qarz = State()

# ================== ASOSIY MENYU ==================
def asosiy_menyu():
    """Asosiy menyu tugmalari"""
    keyboard = ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="💰 Zakot hisoblash")],
            [KeyboardButton(text="🌙 Fitr sadaqa"), KeyboardButton(text="☕ Fidya")],
            [KeyboardButton(text="📖 Ma'lumot"), KeyboardButton(text="👤 Profil")]
        ],
        resize_keyboard=True,
        input_field_placeholder="Menyudan birini tanlang..."
    )
    return keyboard

# ================== ORQAGA TUGMASI ==================
def orqaga_tugma():
    """Orqaga qaytish uchun inline tugma"""
    keyboard = InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="🔙 Bosh menyu", callback_data="bosh_menyu")]
        ]
    )
    return keyboard

# ================== /START ==================
@dp.message(Command("start"))
@dp.message(F.text == "🔙 Bosh menyu")
async def start(message: types.Message, state: FSMContext):
    await state.clear()
    await message.answer(
        "👋 Assalomu alaykum!\n\n"
        "🕌 Zakot • Fitr • Fidya botiga xush kelibsiz!\n\n"
        "Iltimos, ismingizni kiriting:",
        reply_markup=ReplyKeyboardRemove()
    )
    await state.set_state(StartState.ism)

# ================== ISM QABUL QILISH ==================
@dp.message(StartState.ism)
async def ism_qabul(message: types.Message, state: FSMContext):
    ism = message.text.strip()
    user = message.from_user

    # Foydalanuvchi ma'lumotlarini saqlash
    await state.update_data(ism=ism, user_id=user.id, username=user.username)

    # Admin uchun xabar
    admin_text = (
        "🆕 YANGI FOYDALANUVCHI RO‘YXATDAN O‘TDI\n\n"
        f"📝 Ismi: {ism}\n"
        f"👤 Telegram: {user.full_name}\n"
        f"🔗 Username: @{user.username if user.username else 'yo‘q'}\n"
        f"🆔 ID: {user.id}\n"
        f"🕒 Vaqt: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )

    try:
        await bot.send_message(ADMIN_ID, admin_text)
    except:
        pass

    # Foydalanuvchiga xush kelibsiz xabari va menyu
    await message.answer(
        f"Xush kelibsiz, {ism}! 😊\n\n"
        "Quyidagi menyudan kerakli bo'limni tanlang:",
        reply_markup=asosiy_menyu()
    )

# ================== MENYU TUGMALARINI QAYTA ISHLASH ==================
@dp.message(F.text == "💰 Zakot hisoblash")
async def zakot_menu(message: types.Message, state: FSMContext):
    # Avvalgi holatni tozalash
    await state.clear()
    
    # Inline tugma bilan YouTube video
    keyboard = InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="🎥 Zakot haqida video", url="https://youtu.be/8IPeMN6IVEg?si=z-HaW_D4xmLV2UoS")],
            [InlineKeyboardButton(text="▶️ Zakot hisoblashni boshlash", callback_data="zakot_boshlash")]
        ]
    )
    
    await message.answer(
        "💰 ZAKOT HISOBI\n\n"
        "Zakot – islomning besh ustunidan biri. Mol-mulkning 2.5% ini muhtojlarga berish.\n\n"
        "📌 2026-yil uchun nisob miqdori: 100,000,000 so‘m\n\n"
        "Zakot hisoblashni boshlash uchun pastdagi tugmani bosing:",
        reply_markup=keyboard
    )

@dp.message(F.text == "🌙 Fitr sadaqa")
async def fitr_menu(message: types.Message):
    text = "🌙 FITR SADAQA MIQDORLARI (2026):\n\n"
    for nom, summa in FITR.items():
        text += f"• {nom} — {summa:,} so‘m\n"
    
    text += "\n📌 Fitr sadaqa Ramazon hayitidan oldin beriladi."
    
    await message.answer(text, reply_markup=orqaga_tugma())

@dp.message(F.text == "☕ Fidya")
async def fidya_menu(message: types.Message):
    text = (
        "☕ FIDYA MIQDORI\n\n"
        f"1 kun uchun fidya: {FIDYA_BIR_KUN:,} so‘m\n\n"
        "Fidya – ro'za tutishga qodir bo'lmagan (doimiy kasal, keksa) kishilar har bir kun uchun beradigan to'lov.\n\n"
        "📌 Masalan, 30 kun uchun: {:,} so‘m".format(FIDYA_BIR_KUN * 30)
    )
    await message.answer(text, reply_markup=orqaga_tugma())

@dp.message(F.text == "📖 Ma'lumot")
async def malumot_menu(message: types.Message):
    text = (
        "📖 BOT HAQIDA MA'LUMOT\n\n"
        "🕌 Zakot • Fitr • Fidya boti\n\n"
        "Bu bot orqali siz:\n"
        "✅ Zakot hisoblashingiz\n"
        "✅ Fitr sadaqa miqdorlarini bilishingiz\n"
        "✅ Fidya miqdorlarini bilishingiz mumkin\n\n"
        "📅 2026-yil Fatvo markazi qarorlariga asosan\n\n"
        "👨‍💻 Admin: @Sizning_username"
    )
    await message.answer(text, reply_markup=orqaga_tugma())

@dp.message(F.text == "👤 Profil")
async def profil_menu(message: types.Message, state: FSMContext):
    data = await state.get_data()
    ism = data.get('ism', 'Noma\'lum')
    
    text = (
        f"👤 PROFIL MA'LUMOTLARI\n\n"
        f"🆔 ID: {message.from_user.id}\n"
        f"📝 Ism: {ism}\n"
        f"👤 Username: @{message.from_user.username if message.from_user.username else 'yo\'q'}\n"
        f"📅 Qo'shilgan sana: {datetime.now().strftime('%Y-%m-%d')}\n\n"
        "🤲 Xayrli zakot!"
    )
    await message.answer(text, reply_markup=orqaga_tugma())

# ================== CALLBACK QUERY LARNI QAYTA ISHLASH ==================
@dp.callback_query(F.data == "bosh_menyu")
async def bosh_menyu(callback: types.CallbackQuery, state: FSMContext):
    await state.clear()
    await callback.message.delete()
    await callback.message.answer(
        "Bosh menyu:",
        reply_markup=asosiy_menyu()
    )
    await callback.answer()

@dp.callback_query(F.data == "zakot_boshlash")
async def zakot_boshlash(callback: types.CallbackQuery, state: FSMContext):
    await callback.message.delete()
    await callback.message.answer(
        "💰 Zakot hisoblashni boshlaymiz.\n\n"
        "Naqd va kartadagi pulingizni so‘mda kiriting:",
        reply_markup=ReplyKeyboardRemove()
    )
    await state.set_state(ZakotState.pul)
    await callback.answer()

# ================== ZAKOT HISOBI ==================
@dp.message(ZakotState.pul)
async def zakot_pul(message: types.Message, state: FSMContext):
    if not message.text.isdigit():
        await message.answer("❌ Iltimos, faqat raqam kiriting.")
        return
    await state.update_data(pul=float(message.text))
    await message.answer("📦 Savdo mollaringiz qiymati (so‘mda, bo‘lmasa 0):")
    await state.set_state(ZakotState.savdo)

@dp.message(ZakotState.savdo)
async def zakot_savdo(message: types.Message, state: FSMContext):
    if not message.text.isdigit():
        await message.answer("❌ Faqat raqam kiriting.")
        return
    await state.update_data(savdo=float(message.text))
    await message.answer("🪙 Oltiningiz qiymati (so‘mda, bo‘lmasa 0):")
    await state.set_state(ZakotState.oltin)

@dp.message(ZakotState.oltin)
async def zakot_oltin(message: types.Message, state: FSMContext):
    if not message.text.isdigit():
        await message.answer("❌ Faqat raqam kiriting.")
        return
    await state.update_data(oltin=float(message.text))
    await message.answer("🥈 Kumushingiz qiymati (so‘mda, bo‘lmasa 0):")
    await state.set_state(ZakotState.kumush)

@dp.message(ZakotState.kumush)
async def zakot_kumush(message: types.Message, state: FSMContext):
    if not message.text.isdigit():
        await message.answer("❌ Faqat raqam kiriting.")
        return
    await state.update_data(kumush=float(message.text))
    await message.answer("💳 Qarzingiz (so‘mda, bo‘lmasa 0):")
    await state.set_state(ZakotState.qarz)

@dp.message(ZakotState.qarz)
async def zakot_hisob(message: types.Message, state: FSMContext):
    if not message.text.isdigit():
        await message.answer("❌ Faqat raqam kiriting.")
        return

    data = await state.get_data()
    qarz = float(message.text)

    jami = (
        data.get("pul", 0)
        + data.get("savdo", 0)
        + data.get("oltin", 0)
        + data.get("kumush", 0)
        - qarz
    )

    result_text = f"🧮 ZAKOT HISOBI NATIJASI\n\n"
    result_text += f"💰 Naqd pul: {data.get('pul', 0):,.0f} so‘m\n"
    result_text += f"📦 Savdo mollari: {data.get('savdo', 0):,.0f} so‘m\n"
    result_text += f"🪙 Oltin: {data.get('oltin', 0):,.0f} so‘m\n"
    result_text += f"🥈 Kumush: {data.get('kumush', 0):,.0f} so‘m\n"
    result_text += f"💳 Qarz: {qarz:,.0f} so‘m\n"
    result_text += f"─────────────────\n"
    result_text += f"JAMI: {jami:,.0f} so‘m\n\n"

    if jami >= ZAKOT_NISOB:
        zakot = jami * ZAKOT_FOIZ
        result_text += (
            f"✅ Nisob: {jami:,.0f} / {ZAKOT_NISOB:,} so‘m\n"
            f"📌 Sizga zakot BERISH FARZ.\n"
            f"💰 Zakot miqdori (2.5%): {zakot:,.0f} so‘m\n\n"
            "🤲 Allah qabul qilsin!"
        )
    else:
        result_text += (
            f"❌ Nisob: {jami:,.0f} / {ZAKOT_NISOB:,} so‘m\n"
            f"📌 Sizga zakot FARZ EMAS.\n\n"
            "📈 Nisobga yetish uchun yana {:,} so‘m kerak.".format(ZAKOT_NISOB - jami)
        )

    await message.answer(result_text, reply_markup=asosiy_menyu())
    await state.clear()

# ================== WEBHOOK UCHUN STARLETTE SERVER ==================
async def telegram_webhook(request: Request) -> Response:
    """Telegram webhook ni qabul qilish"""
    update_data = await request.json()
    update = types.Update(**update_data)
    await dp.feed_update(bot, update)
    return Response(status_code=200)

async def healthcheck(request: Request) -> PlainTextResponse:
    """Render health check uchun"""
    return PlainTextResponse("OK")

# ================== ASOSIY FUNKSIYA ==================
async def main():
    """Botni webhook bilan ishga tushirish"""
    
    # Webhook URL ni sozlash
    webhook_url = f"{RENDER_URL}/webhook"
    await bot.set_webhook(webhook_url, allowed_updates=dp.resolve_used_update_types())
    logging.info(f"✅ Webhook o'rnatildi: {webhook_url}")
    
    # Starlette app
    starlette_app = Starlette(routes=[
        Route("/webhook", telegram_webhook, methods=["POST"]),
        Route("/healthcheck", healthcheck, methods=["GET"]),
    ])
    
    # Uvicorn server
    config = uvicorn.Config(
        app=starlette_app,
        host="0.0.0.0",
        port=PORT,
        log_level="info"
    )
    server = uvicorn.Server(config)
    await server.serve()

# ================== ISHGA TUSHIRISH ==================
if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logging.info("Bot to'xtatildi")
