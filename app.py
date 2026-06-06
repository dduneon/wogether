import os
import secrets
from dotenv import load_dotenv
load_dotenv()
from functools import wraps
from datetime import date, timedelta, datetime
from flask import (
    Flask, render_template, request, redirect, url_for, flash, abort, session, jsonify
)
from flask_sqlalchemy import SQLAlchemy
from flask_login import (
    LoginManager, UserMixin, login_user, logout_user, current_user, login_required
)
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from sqlalchemy import func
from PIL import Image, ImageOps
from io import BytesIO
from minio import Minio
from minio.error import S3Error
import firebase_admin
from firebase_admin import credentials, messaging as fcm_messaging

# =====================================================================
# Wogether (워게더) - 친구들과 크루를 맺고, 목표를 세우고, 운동을 인증하고,
#                     서로 독촉하며 함께 운동 목표를 달성하는 서비스
# =====================================================================

# --- 1. 앱 설정 ---
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'static/uploads')
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'wogether_dev_secret_change_in_prod')
def _db_uri():
    host = os.environ.get('DB_HOST', 'localhost')
    port = os.environ.get('DB_PORT', '3306')
    user = os.environ.get('DB_USER', 'wogether')
    password = os.environ.get('DB_PASSWORD', '')
    name = os.environ.get('DB_NAME', 'wogether')
    return f'mysql+pymysql://{user}:{password}@{host}:{port}/{name}?charset=utf8mb4'

app.config['SQLALCHEMY_DATABASE_URI'] = _db_uri()
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {'pool_recycle': 280, 'pool_pre_ping': True}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB

app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=365)
app.config['REMEMBER_COOKIE_DURATION'] = timedelta(days=365)

MINIO_ENDPOINT  = os.environ.get('MINIO_ENDPOINT', 'minio:9000')
MINIO_ACCESS_KEY = os.environ.get('MINIO_ACCESS_KEY', 'admin')
MINIO_SECRET_KEY = os.environ.get('MINIO_SECRET_KEY', 'password')
MINIO_BUCKET    = os.environ.get('MINIO_BUCKET', 'wogether')
MINIO_PUBLIC_URL = os.environ.get('MINIO_PUBLIC_URL', f'http://{MINIO_ENDPOINT}')

minio_client = Minio(
    MINIO_ENDPOINT,
    access_key=MINIO_ACCESS_KEY,
    secret_key=MINIO_SECRET_KEY,
    secure=os.environ.get('MINIO_SECURE', 'false').lower() == 'true',
)

def _ensure_bucket():
    if not minio_client.bucket_exists(MINIO_BUCKET):
        minio_client.make_bucket(MINIO_BUCKET)

db = SQLAlchemy(app)

# Firebase Admin 초기화
_firebase_cred_path = os.environ.get('FIREBASE_CREDENTIALS', 'firebase-credentials.json')
if os.path.exists(_firebase_cred_path):
    firebase_admin.initialize_app(credentials.Certificate(_firebase_cred_path))
else:
    # 환경변수로 JSON 내용을 직접 전달하는 경우
    import json as _json
    _firebase_cred_env = os.environ.get('FIREBASE_CREDENTIALS_JSON')
    if _firebase_cred_env:
        _cred_dict = _json.loads(_firebase_cred_env)
        firebase_admin.initialize_app(credentials.Certificate(_cred_dict))

_initialized = False

@app.before_request
def _init_once():
    global _initialized
    if not _initialized:
        db.create_all()
        _ensure_bucket()
        _initialized = True
login_manager = LoginManager(app)
login_manager.login_view = 'login'
login_manager.login_message = "로그인이 필요합니다."


# --- KST 헬퍼 ---
def kst_now():
    """현재 시각을 KST(UTC+9)로 반환"""
    return datetime.utcnow() + timedelta(hours=9)


def week_range_kst(reference=None):
    """KST 기준 이번 주(월~일) 범위를 (월요일 00:00, 다음주 월요일 00:00) UTC datetime으로 반환"""
    ref = reference or kst_now()
    today = ref.date()
    monday = today - timedelta(days=today.weekday())  # 이번 주 월요일 (KST date)
    next_monday = monday + timedelta(days=7)
    # KST date -> UTC datetime 경계 (KST 00:00 == UTC 전날 15:00)
    start_utc = datetime(monday.year, monday.month, monday.day) - timedelta(hours=9)
    end_utc = datetime(next_monday.year, next_monday.month, next_monday.day) - timedelta(hours=9)
    return start_utc, end_utc


@app.template_filter('kst')
def format_kst(utc_datetime):
    if not utc_datetime:
        return ""
    kst_datetime = utc_datetime + timedelta(hours=9)
    return kst_datetime.strftime('%Y년 %m월 %d일 %H:%M')


@app.template_filter('kst_date')
def format_kst_date(utc_datetime):
    """날짜만 표시 (YYYY년 MM월 DD일)"""
    if not utc_datetime:
        return ""
    kst_dt = utc_datetime + timedelta(hours=9)
    return kst_dt.strftime('%Y년 %m월 %d일')

@app.template_filter('kst_short')
def format_kst_short(utc_datetime):
    """상대적 시간 표시 (오늘/어제/N일 전)"""
    if not utc_datetime:
        return ""
    kst_now = datetime.utcnow() + timedelta(hours=9)
    kst_dt = utc_datetime + timedelta(hours=9)
    delta = kst_now.date() - kst_dt.date()
    if delta.days == 0:
        return f"오늘 {kst_dt.strftime('%H:%M')}"
    elif delta.days == 1:
        return "어제"
    elif delta.days < 7:
        return f"{delta.days}일 전"
    else:
        return kst_dt.strftime('%m/%d')


# --- 2. 데이터베이스 모델 ---

class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    nickname = db.Column(db.String(80), nullable=False)
    password_hash = db.Column(db.String(256))
    api_token = db.Column(db.String(64), unique=True, index=True)  # 안드로이드 앱 인증용
    fcm_token = db.Column(db.String(256), nullable=True)           # FCM 푸시 토큰
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    memberships = db.relationship('CrewMembership', backref='user', lazy='dynamic',
                                  cascade='all, delete-orphan')
    goals = db.relationship('Goal', backref='user', lazy='dynamic',
                            cascade='all, delete-orphan')
    workout_logs = db.relationship('WorkoutLog', backref='author', lazy='dynamic',
                                   cascade='all, delete-orphan')

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def generate_token(self):
        self.api_token = secrets.token_hex(32)
        return self.api_token

    @property
    def crews(self):
        """이 유저가 속한 크루 목록"""
        return [m.crew for m in self.memberships]

    def is_member_of(self, crew):
        return CrewMembership.query.filter_by(user_id=self.id, crew_id=crew.id).first() is not None

    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'nickname': self.nickname,
        }

    def __repr__(self):
        return f'<User {self.username}>'


class Crew(db.Model):
    """크루(파티)"""
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), nullable=False)
    description = db.Column(db.String(300), nullable=True)
    owner_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    invite_code = db.Column(db.String(12), unique=True, index=True, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    owner = db.relationship('User', foreign_keys=[owner_id])
    memberships = db.relationship('CrewMembership', backref='crew', lazy='dynamic',
                                  cascade='all, delete-orphan')
    goals = db.relationship('Goal', backref='crew', lazy='dynamic',
                            cascade='all, delete-orphan')
    workout_logs = db.relationship('WorkoutLog', backref='crew', lazy='dynamic',
                                   cascade='all, delete-orphan')

    @staticmethod
    def generate_invite_code():
        while True:
            code = secrets.token_urlsafe(6)[:8]
            if not Crew.query.filter_by(invite_code=code).first():
                return code

    @property
    def members(self):
        return [m.user for m in self.memberships]

    @property
    def member_count(self):
        return self.memberships.count()

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'owner_id': self.owner_id,
            'invite_code': self.invite_code,
            'member_count': self.member_count,
        }

    def __repr__(self):
        return f'<Crew {self.name}>'


class CrewMembership(db.Model):
    """크루 멤버십 (유저 <-> 크루 다대다)"""
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    crew_id = db.Column(db.Integer, db.ForeignKey('crew.id', ondelete='CASCADE'), nullable=False)
    role = db.Column(db.String(20), default='member')  # 'owner' | 'member'
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)

    __table_args__ = (db.UniqueConstraint('user_id', 'crew_id', name='_user_crew_uc'),)


class Goal(db.Model):
    """개인 목표 (크루 내에서 설정, 주당 횟수)"""
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    crew_id = db.Column(db.Integer, db.ForeignKey('crew.id', ondelete='CASCADE'), nullable=False)
    title = db.Column(db.String(120), nullable=False)             # 예: "주 3회 러닝"
    category = db.Column(db.String(40), nullable=False, default='기타')
    description = db.Column(db.String(300), nullable=True)
    frequency_per_week = db.Column(db.Integer, nullable=False, default=3)
    status = db.Column(db.String(20), default='pending')          # pending | approved | rejected
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    approvals = db.relationship('GoalApproval', backref='goal', lazy='dynamic',
                                cascade='all, delete-orphan')

    def approval_state(self):
        """팀원 동의 현황: (동의 수, 전체 대상 수)"""
        total = max(self.crew.member_count - 1, 0)  # 본인 제외
        approved = self.approvals.filter_by(approved=True).count()
        return approved, total

    def refresh_status(self):
        """모든 팀원이 동의하면 approved로 전환"""
        approved, total = self.approval_state()
        if total == 0:
            self.status = 'approved'  # 1인 크루는 자동 승인
        elif approved >= total:
            self.status = 'approved'
        return self.status

    def progress_this_week(self):
        """이번 주 진행률: (인증 횟수, 목표 횟수, 퍼센트)"""
        start_utc, end_utc = week_range_kst()
        done = WorkoutLog.query.filter(
            WorkoutLog.user_id == self.user_id,
            WorkoutLog.crew_id == self.crew_id,
            WorkoutLog.goal_id == self.id,
            WorkoutLog.timestamp >= start_utc,
            WorkoutLog.timestamp < end_utc,
        ).count()
        freq = self.frequency_per_week or 1
        percent = min(100, round(done / freq * 100))
        return done, freq, percent

    def to_dict(self):
        done, freq, percent = self.progress_this_week()
        approved, total = self.approval_state()
        return {
            'id': self.id,
            'user_id': self.user_id,
            'crew_id': self.crew_id,
            'title': self.title,
            'category': self.category,
            'description': self.description,
            'frequency_per_week': self.frequency_per_week,
            'status': self.status,
            'progress': {'done': done, 'target': freq, 'percent': percent},
            'approval': {'approved': approved, 'total': total},
        }


class GoalApproval(db.Model):
    """팀원의 목표 동의"""
    id = db.Column(db.Integer, primary_key=True)
    goal_id = db.Column(db.Integer, db.ForeignKey('goal.id', ondelete='CASCADE'), nullable=False)
    approver_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    approved = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    approver = db.relationship('User', foreign_keys=[approver_id])

    __table_args__ = (db.UniqueConstraint('goal_id', 'approver_id', name='_goal_approver_uc'),)


class WorkoutLog(db.Model):
    """운동 인증 기록"""
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    crew_id = db.Column(db.Integer, db.ForeignKey('crew.id', ondelete='CASCADE'), nullable=False)
    goal_id = db.Column(db.Integer, db.ForeignKey('goal.id', ondelete='SET NULL'), nullable=True)
    workout_type = db.Column(db.String(40), nullable=True)   # 예: 러닝, 헬스, 요가 ...
    caption = db.Column(db.String(300), nullable=True)
    timestamp = db.Column(db.DateTime, index=True, default=datetime.utcnow)

    goal = db.relationship('Goal', foreign_keys=[goal_id])
    images = db.relationship('WorkoutImage', backref='log', lazy=True,
                             cascade='all, delete-orphan')

    @property
    def representative_image_url(self):
        if self.images:
            return self.images[0].image_url
        return None

    @property
    def like_count(self):
        return WorkoutLike.query.filter_by(log_id=self.id).count()

    def is_liked_by(self, user_id):
        return WorkoutLike.query.filter_by(log_id=self.id, user_id=user_id).first() is not None

    def to_dict(self):
        return {
            'id': self.id,
            'user': self.author.to_dict(),
            'crew_id': self.crew_id,
            'goal_id': self.goal_id,
            'workout_type': self.workout_type,
            'caption': self.caption,
            'timestamp': self.timestamp.isoformat() + "Z" if self.timestamp else None,
            'images': [img.image_url for img in self.images],
            'like_count': self.like_count,
        }


class WorkoutImage(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(120), nullable=False)
    log_id = db.Column(db.Integer, db.ForeignKey('workout_log.id', ondelete='CASCADE'), nullable=False)

    @property
    def image_url(self):
        return f'{MINIO_PUBLIC_URL}/{MINIO_BUCKET}/{self.filename}'


class WorkoutLike(db.Model):
    """운동 인증 좋아요"""
    id = db.Column(db.Integer, primary_key=True)
    log_id = db.Column(db.Integer, db.ForeignKey('workout_log.id', ondelete='CASCADE'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    __table_args__ = (db.UniqueConstraint('log_id', 'user_id', name='_log_user_like_uc'),)


class Notification(db.Model):
    """알림 (독촉 등)"""
    id = db.Column(db.Integer, primary_key=True)
    recipient_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    sender_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='SET NULL'), nullable=True)
    crew_id = db.Column(db.Integer, db.ForeignKey('crew.id', ondelete='CASCADE'), nullable=True)
    type = db.Column(db.String(30), default='nudge')   # nudge | goal_request | goal_approved | ...
    message = db.Column(db.String(300), nullable=False)
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    recipient = db.relationship('User', foreign_keys=[recipient_id])
    sender = db.relationship('User', foreign_keys=[sender_id])

    def to_dict(self):
        return {
            'id': self.id,
            'sender': self.sender.to_dict() if self.sender else None,
            'crew_id': self.crew_id,
            'type': self.type,
            'message': self.message,
            'is_read': self.is_read,
            'created_at': self.created_at.isoformat() + "Z" if self.created_at else None,
        }


class CrewActivity(db.Model):
    """크루 피드에 표시되는 시스템 이벤트"""
    id = db.Column(db.Integer, primary_key=True)
    crew_id = db.Column(db.Integer, db.ForeignKey('crew.id', ondelete='CASCADE'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    # join | goal_added | goal_approved | goal_rejected | goal_completed
    event_type = db.Column(db.String(30), nullable=False)
    meta = db.Column(db.String(300), nullable=True)   # JSON 문자열 (goal_title 등)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', foreign_keys=[user_id])
    crew = db.relationship('Crew', foreign_keys=[crew_id])


def record_activity(crew_id, user_id, event_type, **meta):
    import json
    act = CrewActivity(
        crew_id=crew_id, user_id=user_id,
        event_type=event_type,
        meta=json.dumps(meta, ensure_ascii=False) if meta else None,
    )
    db.session.add(act)
    return act


def _check_and_record_streak(crew_id, user_id):
    """오늘 포함 연속으로 운동한 날 수를 계산해 2일 이상이면 streak 활동을 기록한다."""
    kst_today = kst_now().date()

    # 오늘 이미 streak 기록했으면 skip
    today_start_utc = datetime(kst_today.year, kst_today.month, kst_today.day) - timedelta(hours=9)
    today_end_utc = today_start_utc + timedelta(days=1)
    already = CrewActivity.query.filter(
        CrewActivity.crew_id == crew_id,
        CrewActivity.user_id == user_id,
        CrewActivity.event_type == 'streak',
        CrewActivity.created_at >= today_start_utc,
        CrewActivity.created_at < today_end_utc,
    ).first()
    if already:
        return

    # 과거 인증 날짜 목록 (KST 기준)
    logs = WorkoutLog.query.filter(
        WorkoutLog.crew_id == crew_id,
        WorkoutLog.user_id == user_id,
    ).order_by(WorkoutLog.timestamp.desc()).all()

    logged_days = sorted({
        (log.timestamp + timedelta(hours=9)).date()
        for log in logs
    }, reverse=True)

    # 오늘부터 거슬러 올라가며 연속 일수 계산
    streak = 0
    check = kst_today
    for d in logged_days:
        if d == check:
            streak += 1
            check -= timedelta(days=1)
        elif d < check:
            break

    if streak >= 2:
        _STREAK_LABELS = {2: '이틀', 3: '사흘', 4: '나흘', 5: '닷새',
                          6: '엿새', 7: '일주일'}
        label = _STREAK_LABELS.get(streak, f'{streak}일')
        record_activity(crew_id, user_id, 'streak', days=streak, label=label)


@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))


# --- 알림 생성 헬퍼 ---
def push_notification(recipient_id, message, sender_id=None, crew_id=None, n_type='nudge'):
    noti = Notification(
        recipient_id=recipient_id, sender_id=sender_id,
        crew_id=crew_id, type=n_type, message=message,
    )
    db.session.add(noti)

    # FCM 푸시 발송
    _send_fcm(recipient_id, message, n_type)
    return noti


def _send_fcm(recipient_id, message, n_type='nudge'):
    """FCM 푸시 알림 발송. 토큰이 없거나 Firebase 미설정이면 조용히 스킵."""
    try:
        if not firebase_admin._apps:
            return
        recipient = User.query.get(recipient_id)
        if not recipient or not recipient.fcm_token:
            return
        title_map = {
            'nudge': '👉 운동하라고 콕!',
            'goal_request': '🎯 목표 승인 요청',
            'goal_approved': '🏆 목표가 승인됐어요',
            'join': '🤝 새 크루원',
        }
        title = title_map.get(n_type, '🔔 Wogether')
        fcm_messaging.send(fcm_messaging.Message(
            token=recipient.fcm_token,
            notification=fcm_messaging.Notification(title=title, body=message),
            android=fcm_messaging.AndroidConfig(priority='high'),
        ))
    except Exception:
        pass


# --- 파일 저장 헬퍼 ---
def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def save_optimized_image(file):
    """업로드 이미지를 WebP로 최적화해 MinIO에 저장하고 파일명 반환"""
    base = f"{datetime.utcnow().strftime('%Y%m%d%H%M%S%f')}_{secure_filename(file.filename)}"
    img = Image.open(file)
    img = ImageOps.exif_transpose(img)  # EXIF 회전 정보 적용 후 태그 제거
    img.thumbnail((1080, 1080))
    if img.mode != 'RGB':
        img = img.convert('RGB')
    filename = base.rsplit('.', 1)[0] + '.webp'
    buf = BytesIO()
    img.save(buf, 'WEBP', quality=80)
    buf.seek(0)
    _ensure_bucket()
    minio_client.put_object(
        MINIO_BUCKET, filename, buf, length=buf.getbuffer().nbytes,
        content_type='image/webp',
    )
    return filename


# =====================================================================
# 3. 웹 - 인증 라우트
# =====================================================================

@app.route('/signup', methods=['GET', 'POST'])
def signup():
    if current_user.is_authenticated:
        return redirect(url_for('index'))

    if request.method == 'POST':
        username = request.form['username']
        nickname = request.form['nickname']
        password = request.form['password']

        if User.query.filter_by(username=username).first():
            flash('이미 존재하는 아이디입니다.')
            return redirect(url_for('signup'))

        new_user = User(username=username, nickname=nickname)
        new_user.set_password(password)
        new_user.generate_token()
        db.session.add(new_user)
        db.session.commit()

        flash('회원가입 성공! 로그인해주세요.')
        return redirect(url_for('login'))

    return render_template('signup.html')


@app.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('index'))

    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        user = User.query.filter_by(username=username).first()

        if user is None or not user.check_password(password):
            flash('아이디 또는 비밀번호가 올바르지 않습니다.')
            return redirect(url_for('login'))

        login_user(user, remember=True)
        session.permanent = True
        return redirect(url_for('index'))

    return render_template('login.html')


@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('index'))


# =====================================================================
# 4. 웹 - 메인 / 크루
# =====================================================================

@app.route('/')
def index():
    if not current_user.is_authenticated:
        return render_template('landing.html')

    crews = current_user.crews
    unread = Notification.query.filter_by(recipient_id=current_user.id, is_read=False).count()
    start_utc, end_utc = week_range_kst()

    # 이번 주 전체 인증 수 (모든 크루 합산)
    total_logs_this_week = WorkoutLog.query.filter(
        WorkoutLog.user_id == current_user.id,
        WorkoutLog.timestamp >= start_utc,
        WorkoutLog.timestamp < end_utc,
    ).count()

    # 가장 최근 인증한 크루 (퀵 액션용)
    latest_log = WorkoutLog.query.filter_by(user_id=current_user.id)\
        .order_by(WorkoutLog.timestamp.desc()).first()
    quick_crew = latest_log.crew if latest_log else (crews[0] if crews else None)

    # 크루별 상세 데이터
    crews_data = []
    for crew in crews:
        # 내 이번 주 진행률
        my_goals = Goal.query.filter_by(user_id=current_user.id, crew_id=crew.id, status='approved').all()
        if my_goals:
            percents = [g.progress_this_week()[2] for g in my_goals]
            my_pct = round(sum(percents) / len(percents))
        else:
            my_pct = 0

        # 크루 전체 이번 주 인증 수
        crew_logs_count = WorkoutLog.query.filter(
            WorkoutLog.crew_id == crew.id,
            WorkoutLog.timestamp >= start_utc,
            WorkoutLog.timestamp < end_utc,
        ).count()

        # 마지막 인증 (크루 전체)
        last_log = crew.workout_logs.order_by(WorkoutLog.timestamp.desc()).first()

        # 내가 동의 안 한 대기 목표 수
        pending_goals = Goal.query.filter(
            Goal.crew_id == crew.id,
            Goal.status == 'pending',
            Goal.user_id != current_user.id,
        ).all()
        pending_count = sum(
            1 for g in pending_goals
            if not g.approvals.filter_by(approver_id=current_user.id).first()
        )

        crews_data.append({
            'crew': crew,
            'my_pct': my_pct,
            'crew_logs_count': crew_logs_count,
            'last_log': last_log,
            'pending_count': pending_count,
        })

    return render_template('index.html', crews_data=crews_data, unread=unread,
                           total_logs_this_week=total_logs_this_week, quick_crew=quick_crew)


@app.route('/crew/create', methods=['GET', 'POST'])
@login_required
def create_crew():
    if request.method == 'POST':
        name = request.form['name']
        description = request.form.get('description', '')

        crew = Crew(name=name, description=description, owner_id=current_user.id,
                    invite_code=Crew.generate_invite_code())
        db.session.add(crew)
        db.session.flush()

        membership = CrewMembership(user_id=current_user.id, crew_id=crew.id, role='owner')
        db.session.add(membership)
        db.session.commit()

        flash(f'크루 "{crew.name}" 생성 완료! 초대코드: {crew.invite_code}')
        return redirect(url_for('crew_detail', crew_id=crew.id))

    return render_template('create_crew.html')


@app.route('/crew/join', methods=['POST'])
@login_required
def join_crew():
    code = request.form.get('invite_code', '').strip()
    return redirect(url_for('join_crew_link', code=code))


@app.route('/join/<code>', methods=['GET', 'POST'])
@login_required
def join_crew_link(code):
    """초대링크로 크루 합류 (GET: 확인 화면, POST: 실제 가입)"""
    crew = Crew.query.filter_by(invite_code=code).first_or_404()

    if current_user.is_member_of(crew):
        flash('이미 가입한 크루입니다.')
        return redirect(url_for('crew_detail', crew_id=crew.id))

    if request.method == 'POST':
        membership = CrewMembership(user_id=current_user.id, crew_id=crew.id, role='member')
        db.session.add(membership)
        for m in crew.memberships:
            if m.user_id != current_user.id:
                push_notification(m.user_id,
                                  f'{current_user.nickname}님이 "{crew.name}" 크루에 합류했어요!',
                                  sender_id=current_user.id, crew_id=crew.id, n_type='join')
        record_activity(crew.id, current_user.id, 'join')
        db.session.commit()
        flash(f'"{crew.name}" 크루에 합류했어요! 🎉')
        return redirect(url_for('crew_detail', crew_id=crew.id))

    return render_template('join_crew.html', crew=crew, code=code)


@app.route('/crew/<int:crew_id>')
@login_required
def crew_detail(crew_id):
    crew = Crew.query.get_or_404(crew_id)
    if not current_user.is_member_of(crew):
        abort(403)

    # 멤버별 이번 주 진행 현황
    members_data = []
    for m in crew.memberships:
        user = m.user
        goals = Goal.query.filter_by(user_id=user.id, crew_id=crew.id).all()
        # 멤버 종합 진행률 (목표들의 평균)
        if goals:
            percents = [g.progress_this_week()[2] for g in goals]
            avg_percent = round(sum(percents) / len(percents))
        else:
            avg_percent = 0
        members_data.append({
            'user': user,
            'role': m.role,
            'goals': goals,
            'avg_percent': avg_percent,
        })

    # 최근 인증 피드 + 시스템 활동 합치기
    import json as _json
    logs = crew.workout_logs.order_by(WorkoutLog.timestamp.desc()).limit(30).all()
    activities = CrewActivity.query.filter_by(crew_id=crew.id)\
        .order_by(CrewActivity.created_at.desc()).limit(30).all()
    for act in activities:
        act.meta_dict = _json.loads(act.meta) if act.meta else {}

    feed_items = sorted(
        [{'type': 'log', 'ts': l.timestamp, 'obj': l} for l in logs] +
        [{'type': 'activity', 'ts': a.created_at, 'obj': a} for a in activities],
        key=lambda x: x['ts'], reverse=True
    )[:40]

    # 내가 승인해야 할 (대기중) 다른 사람 목표
    pending_goals = Goal.query.filter(
        Goal.crew_id == crew.id,
        Goal.status == 'pending',
        Goal.user_id != current_user.id,
    ).all()
    pending_for_me = [
        g for g in pending_goals
        if not g.approvals.filter_by(approver_id=current_user.id).first()
    ]

    return render_template('crew_detail.html', crew=crew, members_data=members_data,
                           logs=logs, feed_items=feed_items, pending_for_me=pending_for_me)


@app.route('/crew/<int:crew_id>/leave', methods=['POST'])
@login_required
def leave_crew(crew_id):
    crew = Crew.query.get_or_404(crew_id)
    membership = CrewMembership.query.filter_by(user_id=current_user.id, crew_id=crew.id).first()
    if not membership:
        abort(403)

    if crew.owner_id == current_user.id:
        flash('크루장은 탈퇴할 수 없습니다. 크루를 삭제하거나 위임하세요.')
        return redirect(url_for('crew_detail', crew_id=crew.id))

    db.session.delete(membership)
    db.session.commit()
    flash(f'"{crew.name}" 크루에서 나왔습니다.')
    return redirect(url_for('index'))


# =====================================================================
# 5. 웹 - 목표
# =====================================================================

@app.route('/crew/<int:crew_id>/goal/create', methods=['GET', 'POST'])
@login_required
def create_goal(crew_id):
    crew = Crew.query.get_or_404(crew_id)
    if not current_user.is_member_of(crew):
        abort(403)

    if request.method == 'POST':
        title = request.form['title']
        category = request.form.get('category', '기타')
        description = request.form.get('description', '').strip() or None
        frequency = int(request.form.get('frequency_per_week', 3))

        goal = Goal(user_id=current_user.id, crew_id=crew.id,
                    title=title, category=category, description=description,
                    frequency_per_week=frequency, status='pending')
        db.session.add(goal)
        db.session.flush()
        goal.refresh_status()  # 1인 크루면 자동 승인

        # 팀원들에게 동의 요청 알림
        for m in crew.memberships:
            if m.user_id != current_user.id:
                push_notification(m.user_id,
                                  f'{current_user.nickname}님의 목표 "{title}"에 동의해주세요.',
                                  sender_id=current_user.id, crew_id=crew.id,
                                  n_type='goal_request')
        record_activity(crew.id, current_user.id, 'goal_added',
                        goal_title=title, category=category, frequency=frequency)
        db.session.commit()

        flash('목표를 등록했어요! 팀원들의 동의를 기다립니다.')
        return redirect(url_for('crew_detail', crew_id=crew.id))

    return render_template('create_goal.html', crew=crew)


@app.route('/goal/<int:goal_id>/approve', methods=['POST'])
@login_required
def approve_goal(goal_id):
    goal = Goal.query.get_or_404(goal_id)
    if not current_user.is_member_of(goal.crew):
        abort(403)
    if goal.user_id == current_user.id:
        flash('본인 목표는 동의할 수 없습니다.')
        return redirect(url_for('crew_detail', crew_id=goal.crew_id))

    existing = goal.approvals.filter_by(approver_id=current_user.id).first()
    if not existing:
        approval = GoalApproval(goal_id=goal.id, approver_id=current_user.id, approved=True)
        db.session.add(approval)
        db.session.flush()
        prev_status = goal.status
        goal.refresh_status()
        if goal.status == 'approved' and prev_status != 'approved':
            push_notification(goal.user_id,
                              f'목표 "{goal.title}"가 모든 팀원의 동의를 받았어요! 💪',
                              crew_id=goal.crew_id, n_type='goal_approved')
            record_activity(goal.crew_id, goal.user_id, 'goal_approved',
                            goal_title=goal.title)
        db.session.commit()
        flash('목표에 동의했습니다.')

    return redirect(url_for('crew_detail', crew_id=goal.crew_id))


@app.route('/goal/<int:goal_id>/delete', methods=['POST'])
@login_required
def delete_goal(goal_id):
    goal = Goal.query.get_or_404(goal_id)
    if goal.user_id != current_user.id:
        abort(403)
    crew_id = goal.crew_id
    db.session.delete(goal)
    db.session.commit()
    flash('목표를 삭제했습니다.')
    return redirect(url_for('crew_detail', crew_id=crew_id))


# =====================================================================
# 6. 웹 - 운동 인증
# =====================================================================

@app.route('/crew/<int:crew_id>/log', methods=['GET', 'POST'])
@login_required
def create_log(crew_id):
    crew = Crew.query.get_or_404(crew_id)
    if not current_user.is_member_of(crew):
        abort(403)

    my_goals = Goal.query.filter_by(user_id=current_user.id, crew_id=crew.id,
                                    status='approved').all()

    if request.method == 'POST':
        files = request.files.getlist('photo')
        caption = request.form.get('caption')
        workout_type = request.form.get('workout_type')
        goal_id = request.form.get('goal_id', type=int)

        if not files or files[0].filename == '':
            flash('인증 사진을 최소 한 장 이상 올려주세요.')
            return redirect(request.url)

        log = WorkoutLog(user_id=current_user.id, crew_id=crew.id,
                         goal_id=goal_id if goal_id else None,
                         workout_type=workout_type, caption=caption)
        db.session.add(log)
        db.session.flush()

        for file in files:
            if file and allowed_file(file.filename):
                filename = save_optimized_image(file)
                db.session.add(WorkoutImage(filename=filename, log=log))

        # 연결된 목표의 주간 달성 여부 체크 (이번 인증으로 목표 횟수를 채웠는지)
        if goal_id:
            linked_goal = Goal.query.get(goal_id)
            if linked_goal:
                db.session.flush()
                done, target, _ = linked_goal.progress_this_week()
                if done >= target:
                    # 이번 주 처음으로 달성했을 때만 (이미 activity가 있으면 skip)
                    from sqlalchemy import func
                    start_utc, end_utc = week_range_kst()
                    already = CrewActivity.query.filter(
                        CrewActivity.crew_id == crew.id,
                        CrewActivity.user_id == current_user.id,
                        CrewActivity.event_type == 'goal_completed',
                        CrewActivity.created_at >= start_utc,
                        CrewActivity.created_at < end_utc,
                    ).first()
                    if not already:
                        record_activity(crew.id, current_user.id, 'goal_completed',
                                        goal_title=linked_goal.title, done=done, target=target)

        # 연속 운동 스트릭 체크
        _check_and_record_streak(crew.id, current_user.id)

        db.session.commit()
        flash('운동 인증 완료! 🔥')
        return redirect(url_for('crew_detail', crew_id=crew.id))

    goals_data = []
    for g in my_goals:
        done, freq, pct = g.progress_this_week()
        goals_data.append({
            'id': g.id,
            'title': g.title,
            'category': g.category,
            'frequency_per_week': g.frequency_per_week,
            'done': done,
            'freq': freq,
            'pct': pct,
        })
    return render_template('create_log.html', crew=crew, my_goals=my_goals, goals_data=goals_data)


@app.route('/log/<int:log_id>/like', methods=['POST'])
@login_required
def toggle_like(log_id):
    log = WorkoutLog.query.get_or_404(log_id)
    existing = WorkoutLike.query.filter_by(log_id=log.id, user_id=current_user.id).first()
    if existing:
        db.session.delete(existing)
        liked = False
    else:
        db.session.add(WorkoutLike(log_id=log.id, user_id=current_user.id))
        liked = True
    db.session.commit()
    count = WorkoutLike.query.filter_by(log_id=log.id).count()
    return jsonify({'liked': liked, 'count': count})


@app.route('/log/<int:log_id>/delete', methods=['POST'])
@login_required
def delete_log(log_id):
    log = WorkoutLog.query.get_or_404(log_id)
    if log.user_id != current_user.id:
        abort(403)
    crew_id = log.crew_id
    for image in log.images:
        try:
            minio_client.remove_object(MINIO_BUCKET, image.filename)
        except S3Error:
            pass
    db.session.delete(log)
    db.session.commit()
    flash('인증 기록을 삭제했습니다.')
    return redirect(url_for('crew_detail', crew_id=crew_id))


# =====================================================================
# 7. 웹 - 독촉(Nudge) & 알림
# =====================================================================

NUDGE_COOLDOWN_MINUTES = 5

@app.route('/crew/<int:crew_id>/nudge/<int:target_user_id>', methods=['POST'])
@login_required
def nudge(crew_id, target_user_id):
    crew = Crew.query.get_or_404(crew_id)
    if not current_user.is_member_of(crew):
        abort(403)
    target = User.query.get_or_404(target_user_id)
    if not target.is_member_of(crew):
        abort(404)

    cooldown_since = datetime.utcnow() - timedelta(minutes=NUDGE_COOLDOWN_MINUTES)
    recent = Notification.query.filter(
        Notification.recipient_id == target.id,
        Notification.sender_id == current_user.id,
        Notification.crew_id == crew.id,
        Notification.type == 'nudge',
        Notification.created_at >= cooldown_since,
    ).first()

    if recent:
        flash(f'독촉은 {NUDGE_COOLDOWN_MINUTES}분에 한 번만 보낼 수 있어요.')
        return redirect(url_for('crew_detail', crew_id=crew.id))

    push_notification(
        target.id,
        f'{current_user.nickname}님이 "{crew.name}"에서 운동하라고 콕! 찔렀어요 👉',
        sender_id=current_user.id, crew_id=crew.id, n_type='nudge',
    )
    db.session.commit()
    flash(f'{target.nickname}님에게 독촉 알림을 보냈어요!')
    return redirect(url_for('crew_detail', crew_id=crew.id))


@app.route('/notifications')
@login_required
def notifications():
    notis = Notification.query.filter_by(recipient_id=current_user.id)\
        .order_by(Notification.created_at.desc()).limit(50).all()
    Notification.query.filter_by(recipient_id=current_user.id, is_read=False)\
        .update({'is_read': True})
    db.session.commit()
    return render_template('notifications.html', notifications=notis)


@app.route('/notifications/popup')
@login_required
def notifications_popup():
    """네브바 팝업용 JSON — 최근 20개 + 읽음 처리"""
    notis = Notification.query.filter_by(recipient_id=current_user.id)\
        .order_by(Notification.created_at.desc()).limit(20).all()
    data = [n.to_dict() for n in notis]
    Notification.query.filter_by(recipient_id=current_user.id, is_read=False)\
        .update({'is_read': True})
    db.session.commit()
    return jsonify(data)


@app.route('/notifications/unread-count')
@login_required
def notifications_unread_count():
    count = Notification.query.filter_by(recipient_id=current_user.id, is_read=False).count()
    return jsonify({'count': count})


# =====================================================================
# 8. 안드로이드용 REST JSON API  (토큰 인증)
# =====================================================================

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth = request.headers.get('Authorization', '')
        token = auth.replace('Bearer ', '').strip()
        if not token:
            return jsonify({'error': 'token required'}), 401
        user = User.query.filter_by(api_token=token).first()
        if not user:
            return jsonify({'error': 'invalid token'}), 401
        request.api_user = user
        return f(*args, **kwargs)
    return decorated


@app.route('/api/signup', methods=['POST'])
def api_signup():
    data = request.get_json(force=True)
    username = data.get('username')
    nickname = data.get('nickname')
    password = data.get('password')
    if not all([username, nickname, password]):
        return jsonify({'error': '아이디, 닉네임, 비밀번호를 모두 입력해주세요.'}), 400
    if User.query.filter_by(username=username).first():
        return jsonify({'error': '이미 사용 중인 아이디예요.'}), 409

    user = User(username=username, nickname=nickname)
    user.set_password(password)
    user.generate_token()
    db.session.add(user)
    db.session.commit()
    return jsonify({'token': user.api_token, 'user': user.to_dict()}), 201


@app.route('/api/login', methods=['POST'])
def api_login():
    data = request.get_json(force=True)
    user = User.query.filter_by(username=data.get('username')).first()
    if not user or not user.check_password(data.get('password', '')):
        return jsonify({'error': '아이디 또는 비밀번호가 올바르지 않아요.'}), 401
    if not user.api_token:
        user.generate_token()
        db.session.commit()
    return jsonify({'token': user.api_token, 'user': user.to_dict()})


@app.route('/api/me')
@token_required
def api_me():
    return jsonify(request.api_user.to_dict())


@app.route('/api/fcm-token', methods=['POST'])
@token_required
def api_fcm_token():
    user = request.api_user
    data = request.get_json(force=True)
    token = data.get('token', '').strip()
    if token:
        user.fcm_token = token
        db.session.commit()
    return jsonify({'ok': True})


@app.route('/api/crews', methods=['GET', 'POST'])
@token_required
def api_crews():
    user = request.api_user
    if request.method == 'POST':
        data = request.get_json(force=True)
        if not data.get('name'):
            return jsonify({'error': '크루 이름을 입력해주세요.'}), 400
        crew = Crew(name=data['name'], description=data.get('description', ''),
                    owner_id=user.id, invite_code=Crew.generate_invite_code())
        db.session.add(crew)
        db.session.flush()
        db.session.add(CrewMembership(user_id=user.id, crew_id=crew.id, role='owner'))
        db.session.commit()
        return jsonify(crew.to_dict()), 201

    return jsonify([c.to_dict() for c in user.crews])


@app.route('/api/crews/join', methods=['POST'])
@token_required
def api_join_crew():
    user = request.api_user
    data = request.get_json(force=True)
    crew = Crew.query.filter_by(invite_code=data.get('invite_code', '').strip()).first()
    if not crew:
        return jsonify({'error': '유효하지 않은 초대코드예요.'}), 404
    if user.is_member_of(crew):
        return jsonify({'error': '이미 가입된 크루예요.'}), 409
    db.session.add(CrewMembership(user_id=user.id, crew_id=crew.id, role='member'))
    db.session.flush()
    for m in crew.memberships:
        if m.user_id != user.id:
            push_notification(m.user_id, f'{user.nickname}님이 "{crew.name}" 크루에 합류했어요!',
                              sender_id=user.id, crew_id=crew.id, n_type='join')
    record_activity(crew.id, user.id, 'join')
    db.session.commit()
    return jsonify(crew.to_dict())


@app.route('/api/crews/<int:crew_id>')
@token_required
def api_crew_detail(crew_id):
    user = request.api_user
    crew = Crew.query.get_or_404(crew_id)
    if not user.is_member_of(crew):
        return jsonify({'error': 'forbidden'}), 403

    import json as _json
    members = []
    for m in crew.memberships:
        goals = Goal.query.filter_by(user_id=m.user_id, crew_id=crew.id).all()
        percents = [g.progress_this_week()[2] for g in goals] or [0]
        members.append({
            'user': m.user.to_dict(),
            'role': m.role,
            'avg_percent': round(sum(percents) / len(percents)),
            'goals': [g.to_dict() for g in goals],
        })

    # 피드 (인증 + 활동)
    logs = crew.workout_logs.order_by(WorkoutLog.timestamp.desc()).limit(30).all()
    activities = CrewActivity.query.filter_by(crew_id=crew.id)\
        .order_by(CrewActivity.created_at.desc()).limit(30).all()

    feed_items = sorted(
        [{'type': 'log', 'ts': l.timestamp.isoformat() + "Z", 'data': {
            **l.to_dict(),
            'is_liked': l.is_liked_by(user.id),
        }} for l in logs] +
        [{'type': 'activity', 'ts': a.created_at.isoformat() + "Z", 'data': {
            'id': a.id,
            'event_type': a.event_type,
            'user': a.user.to_dict(),
            'meta': _json.loads(a.meta) if a.meta else {},
            'created_at': a.created_at.isoformat() + 'Z',
        }} for a in activities],
        key=lambda x: x['ts'], reverse=True
    )[:40]

    # 내가 동의해야 할 대기 목표
    pending_goals = Goal.query.filter(
        Goal.crew_id == crew.id,
        Goal.status == 'pending',
        Goal.user_id != user.id,
    ).all()
    pending_for_me = [
        g.to_dict() | {'user_nickname': g.user.nickname}
        for g in pending_goals
        if not g.approvals.filter_by(approver_id=user.id).first()
    ]

    return jsonify({
        'crew': crew.to_dict(),
        'members': members,
        'feed_items': feed_items,
        'pending_for_me': pending_for_me,
    })


@app.route('/api/crews/<int:crew_id>/goals', methods=['GET', 'POST'])
@token_required
def api_goals(crew_id):
    user = request.api_user
    crew = Crew.query.get_or_404(crew_id)
    if not user.is_member_of(crew):
        return jsonify({'error': 'forbidden'}), 403

    if request.method == 'POST':
        data = request.get_json(force=True)
        if not data.get('title'):
            return jsonify({'error': '목표 이름을 입력해주세요.'}), 400
        goal = Goal(user_id=user.id, crew_id=crew.id,
                    title=data['title'],
                    category=data.get('category', '기타'),
                    description=data.get('description', ''),
                    frequency_per_week=int(data.get('frequency_per_week', 3)),
                    status='pending')
        db.session.add(goal)
        db.session.flush()
        goal.refresh_status()
        for m in crew.memberships:
            if m.user_id != user.id:
                push_notification(m.user_id,
                                  f'{user.nickname}님의 목표 "{goal.title}"에 동의해주세요.',
                                  sender_id=user.id, crew_id=crew.id, n_type='goal_request')
        record_activity(crew.id, user.id, 'goal_added',
                        goal_title=goal.title, frequency=goal.frequency_per_week)
        db.session.commit()
        return jsonify(goal.to_dict()), 201

    goals = Goal.query.filter_by(crew_id=crew.id).all()
    return jsonify([g.to_dict() for g in goals])


@app.route('/api/goals/<int:goal_id>/approve', methods=['POST'])
@token_required
def api_approve_goal(goal_id):
    user = request.api_user
    goal = Goal.query.get_or_404(goal_id)
    if not user.is_member_of(goal.crew) or goal.user_id == user.id:
        return jsonify({'error': 'forbidden'}), 403
    if not goal.approvals.filter_by(approver_id=user.id).first():
        db.session.add(GoalApproval(goal_id=goal.id, approver_id=user.id, approved=True))
        db.session.flush()
        prev = goal.status
        goal.refresh_status()
        if goal.status == 'approved' and prev != 'approved':
            push_notification(goal.user_id, f'목표 "{goal.title}"가 모든 팀원의 동의를 받았어요!',
                              crew_id=goal.crew_id, n_type='goal_approved')
            record_activity(goal.crew_id, goal.user_id, 'goal_approved',
                            goal_title=goal.title)
        db.session.commit()
    return jsonify(goal.to_dict())


@app.route('/api/crews/<int:crew_id>/logs', methods=['GET', 'POST'])
@token_required
def api_logs(crew_id):
    user = request.api_user
    crew = Crew.query.get_or_404(crew_id)
    if not user.is_member_of(crew):
        return jsonify({'error': 'forbidden'}), 403

    if request.method == 'POST':
        # multipart/form-data: photo 파일들 + 텍스트 필드
        files = request.files.getlist('photo')
        log = WorkoutLog(user_id=user.id, crew_id=crew.id,
                         goal_id=request.form.get('goal_id', type=int) or None,
                         workout_type=request.form.get('workout_type'),
                         caption=request.form.get('caption'))
        db.session.add(log)
        db.session.flush()
        for file in files:
            if file and allowed_file(file.filename):
                db.session.add(WorkoutImage(filename=save_optimized_image(file), log=log))

        # 연결된 목표 달성 여부 체크
        if log.goal_id:
            linked_goal = Goal.query.get(log.goal_id)
            if linked_goal:
                db.session.flush()
                done, target, _ = linked_goal.progress_this_week()
                if done >= target:
                    start_utc, end_utc = week_range_kst()
                    already = CrewActivity.query.filter(
                        CrewActivity.crew_id == crew.id,
                        CrewActivity.user_id == user.id,
                        CrewActivity.event_type == 'goal_completed',
                        CrewActivity.created_at >= start_utc,
                        CrewActivity.created_at < end_utc,
                    ).first()
                    if not already:
                        record_activity(crew.id, user.id, 'goal_completed',
                                        goal_title=linked_goal.title, done=done, target=target)

        # 연속 운동 스트릭 체크
        _check_and_record_streak(crew.id, user.id)

        db.session.commit()

        # 크루원들에게 운동 인증 알림 발송 (본인 제외)
        for m in crew.memberships:
            if m.user_id != user.id:
                push_notification(
                    m.user_id,
                    f'{user.nickname}님이 운동 인증을 올렸어요 💪',
                    sender_id=user.id,
                    crew_id=crew.id,
                    n_type='log',
                )
        db.session.commit()

        return jsonify(log.to_dict()), 201

    logs = crew.workout_logs.order_by(WorkoutLog.timestamp.desc()).limit(50).all()
    return jsonify([l.to_dict() for l in logs])


@app.route('/api/crews/<int:crew_id>/nudge/<int:target_user_id>', methods=['POST'])
@token_required
def api_nudge(crew_id, target_user_id):
    user = request.api_user
    crew = Crew.query.get_or_404(crew_id)
    if not user.is_member_of(crew):
        return jsonify({'error': 'forbidden'}), 403
    target = User.query.get_or_404(target_user_id)
    if not target.is_member_of(crew):
        return jsonify({'error': '해당 크루원을 찾을 수 없어요.'}), 404
    push_notification(target.id,
                      f'{user.nickname}님이 "{crew.name}"에서 운동하라고 콕! 찔렀어요 👉',
                      sender_id=user.id, crew_id=crew.id, n_type='nudge')
    db.session.commit()
    return jsonify({'ok': True})


@app.route('/api/notifications', methods=['GET'])
@token_required
def api_notifications():
    user = request.api_user
    notis = Notification.query.filter_by(recipient_id=user.id)\
        .order_by(Notification.created_at.desc()).limit(50).all()
    return jsonify([n.to_dict() for n in notis])


@app.route('/api/notifications/read', methods=['POST'])
@token_required
def api_read_notifications():
    user = request.api_user
    Notification.query.filter_by(recipient_id=user.id, is_read=False)\
        .update({'is_read': True})
    db.session.commit()
    return jsonify({'ok': True})


@app.route('/api/notifications/unread-count', methods=['GET'])
@token_required
def api_notifications_unread_count():
    user = request.api_user
    count = Notification.query.filter_by(recipient_id=user.id, is_read=False).count()
    return jsonify({'count': count})


@app.route('/api/dashboard', methods=['GET'])
@token_required
def api_dashboard():
    """홈 대시보드 — 주간 요약 + 크루별 진행률"""
    user = request.api_user
    crews = user.crews
    start_utc, end_utc = week_range_kst()
    unread = Notification.query.filter_by(recipient_id=user.id, is_read=False).count()

    total_logs_this_week = WorkoutLog.query.filter(
        WorkoutLog.user_id == user.id,
        WorkoutLog.timestamp >= start_utc,
        WorkoutLog.timestamp < end_utc,
    ).count()

    latest_log = WorkoutLog.query.filter_by(user_id=user.id)\
        .order_by(WorkoutLog.timestamp.desc()).first()
    quick_crew_id = (latest_log.crew_id if latest_log else (crews[0].id if crews else None))

    crews_data = []
    for crew in crews:
        my_goals = Goal.query.filter_by(user_id=user.id, crew_id=crew.id, status='approved').all()
        if my_goals:
            percents = [g.progress_this_week()[2] for g in my_goals]
            my_pct = round(sum(percents) / len(percents))
        else:
            my_pct = 0

        crew_logs_count = WorkoutLog.query.filter(
            WorkoutLog.crew_id == crew.id,
            WorkoutLog.timestamp >= start_utc,
            WorkoutLog.timestamp < end_utc,
        ).count()

        last_log = crew.workout_logs.order_by(WorkoutLog.timestamp.desc()).first()

        pending_goals = Goal.query.filter(
            Goal.crew_id == crew.id,
            Goal.status == 'pending',
            Goal.user_id != user.id,
        ).all()
        pending_count = sum(
            1 for g in pending_goals
            if not g.approvals.filter_by(approver_id=user.id).first()
        )

        crews_data.append({
            'crew': crew.to_dict(),
            'my_pct': my_pct,
            'crew_logs_count': crew_logs_count,
            'last_log_timestamp': last_log.timestamp.isoformat() + "Z" if last_log else None,
            'pending_count': pending_count,
        })

    return jsonify({
        'unread': unread,
        'total_logs_this_week': total_logs_this_week,
        'quick_crew_id': quick_crew_id,
        'crews_data': crews_data,
    })


@app.route('/api/logs/<int:log_id>', methods=['DELETE'])
@token_required
def api_delete_log(log_id):
    user = request.api_user
    log = WorkoutLog.query.get_or_404(log_id)
    if log.user_id != user.id:
        return jsonify({'error': 'forbidden'}), 403
    for image in log.images:
        try:
            minio_client.remove_object(MINIO_BUCKET, image.filename)
        except S3Error:
            pass
    db.session.delete(log)
    db.session.commit()
    return jsonify({'ok': True})


@app.route('/api/logs/<int:log_id>/like', methods=['POST'])
@token_required
def api_toggle_like(log_id):
    user = request.api_user
    log = WorkoutLog.query.get_or_404(log_id)
    existing = WorkoutLike.query.filter_by(log_id=log.id, user_id=user.id).first()
    if existing:
        db.session.delete(existing)
        liked = False
    else:
        db.session.add(WorkoutLike(log_id=log.id, user_id=user.id))
        liked = True
    db.session.commit()
    count = WorkoutLike.query.filter_by(log_id=log.id).count()
    return jsonify({'liked': liked, 'count': count})


@app.route('/api/goals/<int:goal_id>', methods=['DELETE'])
@token_required
def api_delete_goal(goal_id):
    user = request.api_user
    goal = Goal.query.get_or_404(goal_id)
    if goal.user_id != user.id:
        return jsonify({'error': 'forbidden'}), 403
    db.session.delete(goal)
    db.session.commit()
    return jsonify({'ok': True})


@app.route('/api/crews/<int:crew_id>/leave', methods=['POST'])
@token_required
def api_leave_crew(crew_id):
    user = request.api_user
    crew = Crew.query.get_or_404(crew_id)
    membership = CrewMembership.query.filter_by(user_id=user.id, crew_id=crew.id).first()
    if not membership:
        return jsonify({'error': '크루원이 아니에요.'}), 403
    if crew.owner_id == user.id:
        return jsonify({'error': '크루장은 탈퇴할 수 없습니다.'}), 400
    db.session.delete(membership)
    db.session.commit()
    return jsonify({'ok': True})


# --- 9. 앱 실행 ---
if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        if not os.path.exists(UPLOAD_FOLDER):
            os.makedirs(UPLOAD_FOLDER)
    app.run(host='0.0.0.0', debug=True, port=3030)
