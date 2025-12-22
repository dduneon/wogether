import os
from datetime import date, timedelta, datetime
from flask import Flask, render_template, request, redirect, url_for, flash, abort, session
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, logout_user, current_user, login_required
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from sqlalchemy import func, distinct
import calendar  # 캘린더 출력을 위해

# --- 1. 앱 설정 ---
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'static/uploads')
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your_very_secret_key_change_this'  # 👈 **중요: 실제 배포 시 변경**
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(BASE_DIR, 'owoon.db')
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB

# "영구" 세션의 수명을 365일로 설정
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=365)
# Flask-Login의 "Remember Me" 쿠키 수명을 365일로 설정
app.config['REMEMBER_COOKIE_DURATION'] = timedelta(days=365)

db = SQLAlchemy(app)
login_manager = LoginManager(app)
login_manager.login_view = 'login'  # 로그인이 필요한 페이지 접근 시 'login' 라우트로 리다이렉트
login_manager.login_message = "로그인이 필요합니다."

@app.template_filter('kst')
def format_kst(utc_datetime):
    """UTC 시간을 KST (UTC+9)로 변환하고 포맷팅하는 필터"""
    if not utc_datetime:
        return ""

    # KST는 UTC+9
    kst_datetime = utc_datetime + timedelta(hours=9)

    # 원하는 날짜/시간 형식으로 반환
    return kst_datetime.strftime('%Y년 %m월 %d일 %H:%M')

# --- 2. 데이터베이스 모델 ---

# UserMixin은 Flask-Login이 요구하는 기본 메서드들을 (is_authenticated 등) 포함
class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)  # 아이디
    nickname = db.Column(db.String(80), nullable=False)
    password_hash = db.Column(db.String(128))
    # vvvv 수정: cascade(종속 삭제) 옵션 추가 및 새 관계 정의 vvvv
    posts = db.relationship('Post', backref='author', lazy=True, cascade='all, delete-orphan')
    likes = db.relationship('Like', backref='author', lazy='dynamic', cascade='all, delete-orphan')
    comments = db.relationship('Comment', backref='author', lazy='dynamic', cascade='all, delete-orphan')
    # ^^^^ 수정 완료 ^^^^

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def __repr__(self):
        return f'<User {self.username}>'

# [신규 추가] 사진 테이블
class PostImage(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(120), nullable=False)
    post_id = db.Column(db.Integer, db.ForeignKey('post.id', ondelete='CASCADE'), nullable=False)

    @property
    def image_url(self):
        return url_for('static', filename=f'uploads/{self.filename}')

class Post(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    caption = db.Column(db.String(200), nullable=True)
    timestamp = db.Column(db.DateTime, index=True, default=datetime.utcnow)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)

    images = db.relationship('PostImage', backref='post', lazy=True, cascade='all, delete-orphan')
    # vvvv 수정: 새 관계 정의 vvvv
    likes = db.relationship('Like', backref='post', lazy='dynamic', cascade='all, delete-orphan')
    # (수정) 댓글이 항상 오래된순(asc)으로 정렬되도록 lambda로 기본값 설정
    comments = db.relationship(
        'Comment',
        backref='post',
        lazy='dynamic',
        cascade='all, delete-orphan',
        order_by=lambda: Comment.timestamp.asc() # 👈 이 라인 추가
    )
    # ^^^^ 수정 완료 ^^^^
    # [수정] 대표 이미지(첫 번째 사진) URL을 가져오는 헬퍼 속성
    @property
    def representative_image_url(self):
        if self.images:
            return self.images[0].image_url
        return None # 사진이 없는 경우 (예외 처리)

     # vvvv (추가) 현재 유저가 이 포스트를 '좋아요' 했는지 확인하는 헬퍼 함수 vvvv
    def is_liked_by(self, user):
        # vvvv 이 2줄을 추가하세요 vvvv
        if not user.is_authenticated:
            return False
        # ^^^^ 여기까지 ^^^^
        return Like.query.filter(
            Like.user_id == user.id,
            Like.post_id == self.id
        ).count() > 0
    # ^^^^ 추가 완료 ^^^^

    def __repr__(self):
        return f'<Post {self.id}>'

class Like(db.Model):
    __tablename__ = 'like'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    post_id = db.Column(db.Integer, db.ForeignKey('post.id', ondelete='CASCADE'), nullable=False)

    # 한 유저가 한 포스트에 한 번만 '좋아요' 누를 수 있도록 Unique 제약 설정
    __table_args__ = (db.UniqueConstraint('user_id', 'post_id', name='_user_post_uc'),)

    def __repr__(self):
        return f'<Like {self.user_id} -> {self.post_id}>'

class Comment(db.Model):
    __tablename__ = 'comment'
    id = db.Column(db.Integer, primary_key=True)
    text = db.Column(db.String(300), nullable=False)
    timestamp = db.Column(db.DateTime, index=True, default=datetime.utcnow)

    # 관계 설정 (누가 썼는지, 어느 포스트에 달렸는지)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    post_id = db.Column(db.Integer, db.ForeignKey('post.id', ondelete='CASCADE'), nullable=False)

    def __repr__(self):
        return f'<Comment {self.id} by {self.user_id}>'

# Flask-Login을 위한 사용자 로더
@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))


# --- 3. 인증 관련 라우트 ---

@app.route('/signup', methods=['GET', 'POST'])
def signup():
    if current_user.is_authenticated:
        return redirect(url_for('index'))

    if request.method == 'POST':
        username = request.form['username']
        nickname = request.form['nickname']
        password = request.form['password']

        user_by_username = User.query.filter_by(username=username).first()
        if user_by_username:
            flash('이미 존재하는 아이디입니다.')
            return redirect(url_for('signup'))

        new_user = User(username=username, nickname=nickname)
        new_user.set_password(password)
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

        login_user(user, remember=True)  # Flask-Login을 통해 세션에 사용자 정보 저장
        session.permanent = True

        return redirect(url_for('index'))

    return render_template('login.html')


@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('index'))


# --- 4. 핵심 기능 라우트 ---

@app.route('/')
def index():
    # 처음 접속 시 페이지 1의 게시물 5개만 가져옴
    page = 1
    per_page = 3
    posts = Post.query.order_by(Post.timestamp.desc()).paginate(page=page, per_page=per_page, error_out=False).items
    return render_template('index.html', posts=posts)

@app.route('/load-more')
def load_more():
    # 자바스크립트에서 보낸 페이지 번호를 받음
    page = request.args.get('page', 1, type=int)
    per_page = 3

    pagination = Post.query.order_by(Post.timestamp.desc()).paginate(page=page, per_page=per_page, error_out=False)
    posts = pagination.items

    if not posts:
        return '', 204 # 더 이상 게시물이 없으면 '내용 없음' 상태코드 반환

    # _post_card.html 조각들을 합쳐서 문자열로 반환
    html = ""
    for post in posts:
        html += render_template('_post_card.html', post=post)

    return html

# 파일 확장자 확인
def allowed_file(filename):
    return '.' in filename and \
        filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


@app.route('/create', methods=['GET', 'POST'])
@login_required
def create_post():
    if request.method == 'POST':
        # 'photo'가 getlist로 여러 파일을 받음
        files = request.files.getlist('photo')
        caption = request.form.get('caption') # .get() 사용 권장

        # 파일이 하나도 없는 경우 체크
        if not files or files[0].filename == '':
            flash('사진을 최소 한 장 이상 선택해주세요.')
            return redirect(request.url)

        # 1. Post 객체 먼저 생성 (DB에 저장해야 ID가 생김)
        new_post = Post(caption=caption, author=current_user)
        db.session.add(new_post)
        db.session.flush() # commit 전이지만 id를 생성하기 위해 flush() 사용

        # 2. 파일들을 순회하며 저장 및 DB 연결
        for file in files:
            if file and allowed_file(file.filename):
                filename = f"{datetime.utcnow().strftime('%Y%m%d%H%M%S')}_{secure_filename(file.filename)}"
                filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
                file.save(filepath)

                # PostImage 객체 생성
                new_image = PostImage(filename=filename, post=new_post)
                db.session.add(new_image)

        db.session.commit() # 최종 저장

        flash('오운완 인증! 🥳')
        return redirect(url_for('profile', username=current_user.username))

    return render_template('create_post.html')


@app.route('/profile/<username>')
def profile(username):
    user = User.query.filter_by(username=username).first_or_404()

    # --- 핵심 로직: 통계 계산 ---
    kst_now = datetime.utcnow() + timedelta(hours=9)
    today_kst = kst_now.date() # KST 기준 오늘 날짜 (예: 2025-11-17)
    current_year = today_kst.year
    current_month = today_kst.month

    # 1. 사용자의 모든 운동 기록 (날짜만, 중복 제거)
    workout_dates_query = db.session.query(
        func.date(func.datetime(Post.timestamp, '+9 hours'))
    ).filter(Post.user_id == user.id).distinct().order_by(
        func.date(func.datetime(Post.timestamp, '+9 hours')).desc()
    )

    # 쿼리 결과를 set(날짜 객체)으로 변환
    # 쿼리 결과를 set(날짜 객체)으로 변환
    # r[0]는 'YYYY-MM-DD' 문자열이므로 date 객체로 변환
    # 3. KST 날짜 문자열('YYYY-MM-DD')을 date 객체 set으로 변환
    workout_dates_kst = {
        datetime.strptime(r[0], '%Y-%m-%d').date()
        for r in workout_dates_query.all()
    }
    

    # 2. 연속 운동일 (Streak) 계산
    streak = 0
    check_date = today_kst

    # 오늘(KST) 운동했는지 확인
    if check_date in workout_dates_kst:
        streak += 1
        check_date -= timedelta(days=1)
        # 어제(KST)부터 거슬러 올라가며 확인
        while check_date in workout_dates_kst:
            streak += 1
            check_date -= timedelta(days=1)
    # 오늘(KST) 안 했으면, 어제(KST) 운동했는지 확인
    elif (check_date - timedelta(days=1)) in workout_dates_kst:
        check_date -= timedelta(days=1) # 어제부터 시작
        streak += 1
        check_date -= timedelta(days=1)
        while check_date in workout_dates_kst:
            streak += 1
            check_date -= timedelta(days=1)

    # 5. (수정) 이번 달 운동 일수 (KST 기준)
    start_of_month_kst = date(current_year, current_month, 1)
    monthly_count = sum(1 for d in workout_dates_kst if d >= start_of_month_kst)

    # 6. 캘린더 데이터 생성
    cal_data = calendar.monthcalendar(current_year, current_month)

    # 7. (수정) 이번 달 캘린더에 표시할 날짜 (KST 기준)
    workout_days_this_month = {d.day for d in workout_dates_kst if d.year == current_year and d.month == current_month}

    return render_template(
        'profile.html',
        user=user,
        streak=streak,
        monthly_count=monthly_count,
        calendar_data=cal_data,
        workout_days=workout_days_this_month,
        today=today_kst # KST 오늘 날짜를 템플릿으로 전달
    )

# app.py 파일 맨 아래, if __name__ == '__main__': 구문 *위에* 추가하세요.

@app.route('/post/<int:post_id>/delete', methods=['POST'])
@login_required
def delete_post(post_id):
    post_to_delete = Post.query.get_or_404(post_id)

    if post_to_delete.author != current_user:
        abort(403)

    try:
        # [수정] 연결된 모든 PostImage 파일을 찾아서 실제 파일 삭제
        for image in post_to_delete.images:
            image_path = os.path.join(app.config['UPLOAD_FOLDER'], image.filename)
            if os.path.exists(image_path):
                os.remove(image_path)

        # DB 삭제 (cascade 설정 덕분에 PostImage 테이블 데이터는 자동 삭제됨)
        db.session.delete(post_to_delete)
        db.session.commit()

        flash('게시물이 성공적으로 삭제되었습니다.')

    except Exception as e:
        db.session.rollback()
        flash(f'삭제 중 오류가 발생했습니다: {e}')

    return redirect(url_for('profile', username=current_user.username))

@app.route('/like/<int:post_id>', methods=['POST'])
@login_required
def like_toggle(post_id):
    """좋아요 토글 (누르면 좋아요, 다시 누르면 취소)"""
    post = Post.query.get_or_404(post_id)

    # 이미 좋아요를 눌렀는지 확인
    existing_like = Like.query.filter(
        Like.user_id == current_user.id,
        Like.post_id == post.id
    ).first()

    try:
        if existing_like:
            # 이미 눌렀다면 -> '좋아요' 취소 (DB에서 삭제)
            db.session.delete(existing_like)
            db.session.commit()
        else:
            # 처음 누른다면 -> '좋아요' (DB에 추가)
            new_like = Like(author=current_user, post=post)
            db.session.add(new_like)
            db.session.commit()
    except Exception as e:
        db.session.rollback()
        flash(f"오류가 발생했습니다: {e}")

    # (수정) 'index' 대신 'request.referrer'를 사용해 직전 페이지로 리다이렉트
    return redirect(request.referrer or url_for('index'))


@app.route('/comment/<int:post_id>', methods=['POST'])
@login_required
def add_comment(post_id):
    """댓글 달기"""
    post = Post.query.get_or_404(post_id)
    comment_text = request.form.get('comment_text') # 템플릿 form의 name과 일치

    if not comment_text:
        flash("댓글 내용이 없습니다.")
        return redirect(request.referrer or url_for('index'))

    try:
        new_comment = Comment(text=comment_text, author=current_user, post=post)
        db.session.add(new_comment)
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        flash(f"댓글 작성 중 오류가 발생했습니다: {e}")

    return redirect(request.referrer or url_for('index'))

# --- 5. 앱 실행 ---
if __name__ == '__main__':
    # 앱 실행 전에 데이터베이스 생성
    with app.app_context():
        db.create_all()
        # 업로드 폴더가 없으면 생성
        if not os.path.exists(UPLOAD_FOLDER):
            os.makedirs(UPLOAD_FOLDER)
    app.run(host='0.0.0.0', debug=True)
