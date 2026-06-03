from flask import jsonify, request
from extensions import db
from models import Goal, GoalApproval, Crew, push_notification, record_activity
from . import api_bp, token_required


@api_bp.route('/crews/<int:crew_id>/goals', methods=['GET', 'POST'])
@token_required
def goals(crew_id):
    user = request.api_user
    crew = Crew.query.get_or_404(crew_id)
    if not user.is_member_of(crew):
        return jsonify({'error': 'forbidden'}), 403

    if request.method == 'POST':
        data = request.get_json(force=True)
        if not data.get('title'):
            return jsonify({'error': 'title required'}), 400
        goal = Goal(user_id=user.id, crew_id=crew.id,
                    title=data['title'],
                    category=data.get('category', '기타'),
                    description=data.get('description'),
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
                        goal_title=goal.title, category=goal.category,
                        frequency=goal.frequency_per_week)
        db.session.commit()
        return jsonify(goal.to_dict()), 201

    goals_list = Goal.query.filter_by(crew_id=crew.id).all()
    return jsonify([g.to_dict() for g in goals_list])


@api_bp.route('/goals/<int:goal_id>/approve', methods=['POST'])
@token_required
def approve_goal(goal_id):
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
            push_notification(goal.user_id,
                              f'목표 "{goal.title}"가 모든 팀원의 동의를 받았어요! 💪',
                              crew_id=goal.crew_id, n_type='goal_approved')
            record_activity(goal.crew_id, goal.user_id, 'goal_approved', goal_title=goal.title)
        db.session.commit()
    return jsonify(goal.to_dict())


@api_bp.route('/goals/<int:goal_id>', methods=['DELETE'])
@token_required
def delete_goal(goal_id):
    user = request.api_user
    goal = Goal.query.get_or_404(goal_id)
    if goal.user_id != user.id:
        return jsonify({'error': 'forbidden'}), 403
    db.session.delete(goal)
    db.session.commit()
    return jsonify({'ok': True})
