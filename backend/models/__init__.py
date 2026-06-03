import secrets
import json
from datetime import datetime
from flask import current_app, url_for
from werkzeug.security import generate_password_hash, check_password_hash
from flask_login import UserMixin

from extensions import db
from helpers import week_range_kst


class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    nickname = db.Column(db.String(80), nullable=False)
    password_hash = db.Column(db.String(256))
    api_token = db.Column(db.String(64), unique=True, index=True)
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
        return [m.crew for m in self.memberships]

    def is_member_of(self, crew):
        return CrewMembership.query.filter_by(user_id=self.id, crew_id=crew.id).first() is not None

    def to_dict(self):
        return {'id': self.id, 'username': self.username, 'nickname': self.nickname}


class Crew(db.Model):
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


class CrewMembership(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    crew_id = db.Column(db.Integer, db.ForeignKey('crew.id', ondelete='CASCADE'), nullable=False)
    role = db.Column(db.String(20), default='member')
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)

    __table_args__ = (db.UniqueConstraint('user_id', 'crew_id', name='_user_crew_uc'),)


class Goal(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    crew_id = db.Column(db.Integer, db.ForeignKey('crew.id', ondelete='CASCADE'), nullable=False)
    title = db.Column(db.String(120), nullable=False)
    category = db.Column(db.String(40), nullable=False, default='기타')
    description = db.Column(db.String(300), nullable=True)
    frequency_per_week = db.Column(db.Integer, nullable=False, default=3)
    status = db.Column(db.String(20), default='pending')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    approvals = db.relationship('GoalApproval', backref='goal', lazy='dynamic',
                                cascade='all, delete-orphan')

    def approval_state(self):
        total = max(self.crew.member_count - 1, 0)
        approved = self.approvals.filter_by(approved=True).count()
        return approved, total

    def refresh_status(self):
        approved, total = self.approval_state()
        if total == 0 or approved >= total:
            self.status = 'approved'
        return self.status

    def progress_this_week(self):
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
    id = db.Column(db.Integer, primary_key=True)
    goal_id = db.Column(db.Integer, db.ForeignKey('goal.id', ondelete='CASCADE'), nullable=False)
    approver_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    approved = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    approver = db.relationship('User', foreign_keys=[approver_id])

    __table_args__ = (db.UniqueConstraint('goal_id', 'approver_id', name='_goal_approver_uc'),)


class WorkoutLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    crew_id = db.Column(db.Integer, db.ForeignKey('crew.id', ondelete='CASCADE'), nullable=False)
    goal_id = db.Column(db.Integer, db.ForeignKey('goal.id', ondelete='SET NULL'), nullable=True)
    workout_type = db.Column(db.String(40), nullable=True)
    caption = db.Column(db.String(300), nullable=True)
    timestamp = db.Column(db.DateTime, index=True, default=datetime.utcnow)

    goal = db.relationship('Goal', foreign_keys=[goal_id])
    images = db.relationship('WorkoutImage', backref='log', lazy=True,
                             cascade='all, delete-orphan')

    @property
    def like_count(self):
        return WorkoutLike.query.filter_by(log_id=self.id).count()

    def is_liked_by(self, user_id):
        return WorkoutLike.query.filter_by(log_id=self.id, user_id=user_id).first() is not None

    def to_dict(self, current_user_id=None):
        return {
            'id': self.id,
            'user': self.author.to_dict(),
            'crew_id': self.crew_id,
            'goal_id': self.goal_id,
            'workout_type': self.workout_type,
            'caption': self.caption,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None,
            'images': [img.image_url for img in self.images],
            'like_count': self.like_count,
            'liked': self.is_liked_by(current_user_id) if current_user_id else False,
        }


class WorkoutImage(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(120), nullable=False)
    log_id = db.Column(db.Integer, db.ForeignKey('workout_log.id', ondelete='CASCADE'), nullable=False)

    @property
    def image_url(self):
        return f'/static/uploads/{self.filename}'


class WorkoutLike(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    log_id = db.Column(db.Integer, db.ForeignKey('workout_log.id', ondelete='CASCADE'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    __table_args__ = (db.UniqueConstraint('log_id', 'user_id', name='_log_user_like_uc'),)


class Notification(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    recipient_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    sender_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='SET NULL'), nullable=True)
    crew_id = db.Column(db.Integer, db.ForeignKey('crew.id', ondelete='CASCADE'), nullable=True)
    type = db.Column(db.String(30), default='nudge')
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
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }


class CrewActivity(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    crew_id = db.Column(db.Integer, db.ForeignKey('crew.id', ondelete='CASCADE'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    event_type = db.Column(db.String(30), nullable=False)
    meta = db.Column(db.String(300), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', foreign_keys=[user_id])
    crew = db.relationship('Crew', foreign_keys=[crew_id])


def record_activity(crew_id, user_id, event_type, **meta):
    act = CrewActivity(
        crew_id=crew_id, user_id=user_id,
        event_type=event_type,
        meta=json.dumps(meta, ensure_ascii=False) if meta else None,
    )
    db.session.add(act)
    return act


def push_notification(recipient_id, message, sender_id=None, crew_id=None, n_type='nudge'):
    noti = Notification(
        recipient_id=recipient_id, sender_id=sender_id,
        crew_id=crew_id, type=n_type, message=message,
    )
    db.session.add(noti)
    return noti
