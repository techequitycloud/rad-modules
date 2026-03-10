import os
from urllib.parse import quote_plus
from flask import Flask, jsonify
from sqlalchemy import create_engine, text, Column, Integer
from sqlalchemy.orm import declarative_base, sessionmaker

app = Flask(__name__)

# Database Configuration
db_host = os.environ.get('DB_HOST')
db_name = os.environ.get('DB_NAME')
db_user = os.environ.get('DB_USER')
db_pass = os.environ.get('DB_PASSWORD')
db_port = os.environ.get('DB_PORT', '5432')

# Construct connection string
# URL encode user and password to handle special characters
db_user = quote_plus(db_user) if db_user else db_user
db_pass = quote_plus(db_pass) if db_pass else db_pass

if db_host and db_host.startswith('/'):
    # Unix Socket connection
    # SQLAlchemy format: postgresql://user:password@/dbname?host=/path/to/socket
    db_uri = f"postgresql://{db_user}:{db_pass}@/{db_name}?host={db_host}"
else:
    # TCP connection
    db_uri = f"postgresql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"

# Create Engine with connection pooling
# pool_size=5, max_overflow=10 are reasonable defaults for this scale
engine = create_engine(db_uri, pool_size=5, max_overflow=10)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()

# Define Visitor Model for CRUD demonstration
class Visitor(Base):
    __tablename__ = 'visitors'
    id = Column(Integer, primary_key=True)
    count = Column(Integer, default=0)

# Initialize Database Schema (Simple Migration)
def init_db():
    try:
        Base.metadata.create_all(engine)
        with SessionLocal() as session:
            if session.query(Visitor).count() == 0:
                session.add(Visitor(count=0))
                session.commit()
                print("Initialized visitor counter.")
    except Exception as e:
        print(f"Database initialization warning: {e}")

# Run initialization on startup
init_db()

@app.route('/')
def hello():
    try:
        with SessionLocal() as session:
            # Increment counter
            visitor = session.query(Visitor).first()
            if not visitor:
                visitor = Visitor(count=0)
                session.add(visitor)

            visitor.count += 1
            session.commit()
            count = visitor.count

        return f"Hello from Sample App! Visitor count: {count}"
    except Exception as e:
        # Fallback if DB fails
        return f"Hello from Sample App! (DB unavailable: {str(e)})"

@app.route('/healthz')
def healthz():
    return jsonify({"status": "healthy"}), 200

@app.route('/db')
def db_check():
    try:
        with engine.connect() as conn:
            result = conn.execute(text("SELECT version()"))
            version = result.scalar()
        return jsonify({"status": "connected", "version": version})
    except Exception as e:
        return jsonify({"error": "Database connection failed", "details": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
