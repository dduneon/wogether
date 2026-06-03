import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from flask import Flask
from flask_cors import CORS

from config import Config, UPLOAD_FOLDER
from extensions import db, login_manager


def create_app():
    app = Flask(__name__,
                static_folder=os.path.join(os.path.dirname(__file__), '..', 'static'),
                static_url_path='/static')
    app.config.from_object(Config)

    CORS(app, resources={r'/api/*': {'origins': '*'}})

    db.init_app(app)
    login_manager.init_app(app)

    from models import User

    @login_manager.user_loader
    def load_user(user_id):
        return User.query.get(int(user_id))

    from routes.api import api_bp
    app.register_blueprint(api_bp)

    with app.app_context():
        db.create_all()
        if not os.path.exists(UPLOAD_FOLDER):
            os.makedirs(UPLOAD_FOLDER)

    return app


app = create_app()

if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=True, port=3030)
