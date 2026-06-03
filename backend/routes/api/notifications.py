from flask import jsonify, request
from extensions import db
from models import Notification
from . import api_bp, token_required


@api_bp.route('/notifications')
@token_required
def notifications():
    user = request.api_user
    notis = Notification.query.filter_by(recipient_id=user.id)\
        .order_by(Notification.created_at.desc()).limit(50).all()
    return jsonify([n.to_dict() for n in notis])


@api_bp.route('/notifications/read', methods=['POST'])
@token_required
def read_notifications():
    user = request.api_user
    Notification.query.filter_by(recipient_id=user.id, is_read=False)\
        .update({'is_read': True})
    db.session.commit()
    return jsonify({'ok': True})


@api_bp.route('/notifications/unread-count')
@token_required
def unread_count():
    user = request.api_user
    count = Notification.query.filter_by(recipient_id=user.id, is_read=False).count()
    return jsonify({'count': count})
