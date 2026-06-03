from flask import jsonify, request
from extensions import db
from models import Crew, CrewMembership, Goal, WorkoutLog, Notification, push_notification, record_activity
from helpers import week_range_kst
from . import api_bp, token_required

NUDGE_COOLDOWN_MINUTES = 5


@api_bp.route('/crews', methods=['GET', 'POST'])
@token_required
def crews():
    user = request.api_user
    if request.method == 'POST':
        data = request.get_json(force=True)
        if not data.get('name'):
            return jsonify({'error': 'name required'}), 400
        crew = Crew(name=data['name'], description=data.get('description', ''),
                    owner_id=user.id, invite_code=Crew.generate_invite_code())
        db.session.add(crew)
        db.session.flush()
        db.session.add(CrewMembership(user_id=user.id, crew_id=crew.id, role='owner'))
        db.session.commit()
        return jsonify(crew.to_dict()), 201

    return jsonify([c.to_dict() for c in user.crews])


@api_bp.route('/crews/join', methods=['POST'])
@token_required
def join_crew():
    user = request.api_user
    data = request.get_json(force=True)
    crew = Crew.query.filter_by(invite_code=data.get('invite_code', '').strip()).first()
    if not crew:
        return jsonify({'error': 'invalid invite code'}), 404
    if user.is_member_of(crew):
        return jsonify({'error': 'already a member'}), 409
    db.session.add(CrewMembership(user_id=user.id, crew_id=crew.id, role='member'))
    for m in crew.memberships:
        if m.user_id != user.id:
            push_notification(m.user_id, f'{user.nickname}님이 "{crew.name}" 크루에 합류했어요!',
                              sender_id=user.id, crew_id=crew.id, n_type='join')
    record_activity(crew.id, user.id, 'join')
    db.session.commit()
    return jsonify(crew.to_dict())


@api_bp.route('/crews/<int:crew_id>')
@token_required
def crew_detail(crew_id):
    user = request.api_user
    crew = Crew.query.get_or_404(crew_id)
    if not user.is_member_of(crew):
        return jsonify({'error': 'forbidden'}), 403

    start_utc, end_utc = week_range_kst()
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

    return jsonify({'crew': crew.to_dict(), 'members': members})


@api_bp.route('/crews/<int:crew_id>/leave', methods=['POST'])
@token_required
def leave_crew(crew_id):
    user = request.api_user
    crew = Crew.query.get_or_404(crew_id)
    membership = CrewMembership.query.filter_by(user_id=user.id, crew_id=crew.id).first()
    if not membership:
        return jsonify({'error': 'not a member'}), 403
    if crew.owner_id == user.id:
        return jsonify({'error': 'owner cannot leave — transfer ownership or delete crew'}), 400
    db.session.delete(membership)
    db.session.commit()
    return jsonify({'ok': True})


@api_bp.route('/crews/<int:crew_id>/nudge/<int:target_user_id>', methods=['POST'])
@token_required
def nudge(crew_id, target_user_id):
    from datetime import datetime, timedelta
    user = request.api_user
    crew = Crew.query.get_or_404(crew_id)
    if not user.is_member_of(crew):
        return jsonify({'error': 'forbidden'}), 403
    from models import User as UserModel
    target = UserModel.query.get_or_404(target_user_id)
    if not target.is_member_of(crew):
        return jsonify({'error': 'target not in crew'}), 404

    cooldown_since = datetime.utcnow() - timedelta(minutes=NUDGE_COOLDOWN_MINUTES)
    recent = Notification.query.filter(
        Notification.recipient_id == target.id,
        Notification.sender_id == user.id,
        Notification.crew_id == crew.id,
        Notification.type == 'nudge',
        Notification.created_at >= cooldown_since,
    ).first()
    if recent:
        return jsonify({'error': f'cooldown: {NUDGE_COOLDOWN_MINUTES}분에 한 번만 보낼 수 있어요'}), 429

    push_notification(target.id,
                      f'{user.nickname}님이 "{crew.name}"에서 운동하라고 콕! 찔렀어요 👉',
                      sender_id=user.id, crew_id=crew.id, n_type='nudge')
    db.session.commit()
    return jsonify({'ok': True})
