from flask import Blueprint, jsonify, request
from functools import wraps
from models import User

api_bp = Blueprint('api', __name__, url_prefix='/api')


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


from . import auth, crews, goals, logs, notifications  # noqa: E402, F401
