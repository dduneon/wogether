from flask import jsonify, request
from extensions import db
from models import User
from . import api_bp, token_required


@api_bp.route('/signup', methods=['POST'])
def signup():
    data = request.get_json(force=True)
    username = data.get('username')
    nickname = data.get('nickname')
    password = data.get('password')
    if not all([username, nickname, password]):
        return jsonify({'error': 'username, nickname, password required'}), 400
    if User.query.filter_by(username=username).first():
        return jsonify({'error': 'username already exists'}), 409

    user = User(username=username, nickname=nickname)
    user.set_password(password)
    user.generate_token()
    db.session.add(user)
    db.session.commit()
    return jsonify({'token': user.api_token, 'user': user.to_dict()}), 201


@api_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json(force=True)
    user = User.query.filter_by(username=data.get('username')).first()
    if not user or not user.check_password(data.get('password', '')):
        return jsonify({'error': 'invalid credentials'}), 401
    if not user.api_token:
        user.generate_token()
        db.session.commit()
    return jsonify({'token': user.api_token, 'user': user.to_dict()})


@api_bp.route('/me')
@token_required
def me():
    return jsonify(request.api_user.to_dict())
