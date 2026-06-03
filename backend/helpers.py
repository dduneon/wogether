import os
from datetime import datetime, timedelta
from werkzeug.utils import secure_filename
from PIL import Image

from config import ALLOWED_EXTENSIONS


def kst_now():
    return datetime.utcnow() + timedelta(hours=9)


def week_range_kst(reference=None):
    ref = reference or kst_now()
    today = ref.date()
    monday = today - timedelta(days=today.weekday())
    next_monday = monday + timedelta(days=7)
    start_utc = datetime(monday.year, monday.month, monday.day) - timedelta(hours=9)
    end_utc = datetime(next_monday.year, next_monday.month, next_monday.day) - timedelta(hours=9)
    return start_utc, end_utc


def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def save_optimized_image(file, upload_folder):
    base = f"{datetime.utcnow().strftime('%Y%m%d%H%M%S%f')}_{secure_filename(file.filename)}"
    img = Image.open(file)
    img.thumbnail((1080, 1080))
    if img.mode != 'RGB':
        img = img.convert('RGB')
    filename = base.rsplit('.', 1)[0] + '.webp'
    filepath = os.path.join(upload_folder, filename)
    img.save(filepath, 'WEBP', quality=80)
    return filename
