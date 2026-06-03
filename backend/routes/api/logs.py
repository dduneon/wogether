import os
from flask import jsonify, request, current_app
from extensions import db
from models import (WorkoutLog, WorkoutImage, WorkoutLike, Crew, Goal,
                    CrewActivity, record_activity)
from helpers import allowed_file, save_optimized_image, week_range_kst
from . import api_bp, token_required


@api_bp.route('/crews/<int:crew_id>/logs', methods=['GET', 'POST'])
@token_required
def logs(crew_id):
    user = request.api_user
    crew = Crew.query.get_or_404(crew_id)
    if not user.is_member_of(crew):
        return jsonify({'error': 'forbidden'}), 403

    if request.method == 'POST':
        files = request.files.getlist('photo')
        goal_id = request.form.get('goal_id', type=int) or None
        log = WorkoutLog(user_id=user.id, crew_id=crew.id, goal_id=goal_id,
                         workout_type=request.form.get('workout_type'),
                         caption=request.form.get('caption'))
        db.session.add(log)
        db.session.flush()

        for file in files:
            if file and allowed_file(file.filename):
                filename = save_optimized_image(file, current_app.config['UPLOAD_FOLDER'])
                db.session.add(WorkoutImage(filename=filename, log=log))

        if goal_id:
            linked_goal = Goal.query.get(goal_id)
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

        db.session.commit()
        return jsonify(log.to_dict(current_user_id=user.id)), 201

    logs_list = crew.workout_logs.order_by(WorkoutLog.timestamp.desc()).limit(50).all()
    return jsonify([l.to_dict(current_user_id=user.id) for l in logs_list])


@api_bp.route('/logs/<int:log_id>/like', methods=['POST'])
@token_required
def toggle_like(log_id):
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


@api_bp.route('/logs/<int:log_id>', methods=['DELETE'])
@token_required
def delete_log(log_id):
    user = request.api_user
    log = WorkoutLog.query.get_or_404(log_id)
    if log.user_id != user.id:
        return jsonify({'error': 'forbidden'}), 403
    for image in log.images:
        path = os.path.join(current_app.config['UPLOAD_FOLDER'], image.filename)
        if os.path.exists(path):
            os.remove(path)
    db.session.delete(log)
    db.session.commit()
    return jsonify({'ok': True})
