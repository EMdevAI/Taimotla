from flask import Flask, render_template, request, redirect, url_for, session
from werkzeug.security import generate_password_hash, check_password_hash
from database import obtener_conexion
import re
from functools import wraps

app = Flask(__name__)
app.secret_key = 'tu_clave_secreta_muy_segura_aqui_cambiar_en_produccion'

# ==========================================
# CONFIGURACIÓN DE DIRECTOR POR DEFECTO
# ==========================================
DEFAULT_DIRECTOR = {
    'correo': 'admin@fundacion.com',
    'password': 'admin123',
    'CURP': 'ADMIN000000000000',
    'p_nombre': 'Admin',
    's_nombre': '',
    'p_apellido': 'Director',
    's_apellido': 'Sistema',
    'sexo': 'Otro',
    'fecha_nacimiento': '2000-01-01',
    'telefono': '5555555555'
}

def ensure_default_director():
    """Asegura que exista al menos un director por defecto al iniciar la app"""
    try:
        conn = obtener_conexion()
        cur = conn.cursor()
        
        # Expandir contrasena a varchar(255) en todas las tablas de roles
        tables_with_password = ['director', 'coordinador', 'abogado', 'medico', 'psicologo', 'trabajadorsocial']
        for table in tables_with_password:
            try:
                cur.execute(f'ALTER TABLE {table} ALTER COLUMN "contrasena" TYPE varchar(255)')
                conn.commit()
            except:
                pass
        
        # Generar hash del password por defecto
        default_hash = generate_password_hash(DEFAULT_DIRECTOR['password'])
        
        # Verificar si el director ya existe
        cur.execute('SELECT "CURP" FROM director LIMIT 1')
        director_exists = cur.fetchone()
        
        if not director_exists:
            # Insertar persona
            try:
                cur.execute('''
                    INSERT INTO persona ("CURP", "p_nombre", "s_nombre", "p_apellido", "s_apellido", 
                                       "sexo", "fecha_nacimiento", "telefono", "correo")
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT ("CURP") DO NOTHING
                ''', (
                    DEFAULT_DIRECTOR['CURP'],
                    DEFAULT_DIRECTOR['p_nombre'],
                    DEFAULT_DIRECTOR['s_nombre'],
                    DEFAULT_DIRECTOR['p_apellido'],
                    DEFAULT_DIRECTOR['s_apellido'],
                    DEFAULT_DIRECTOR['sexo'],
                    DEFAULT_DIRECTOR['fecha_nacimiento'],
                    DEFAULT_DIRECTOR['telefono'],
                    DEFAULT_DIRECTOR['correo']
                ))
                conn.commit()
            except Exception as e:
                print(f"[WARNING] Error inserting persona: {e}")
            
            # Insertar director
            try:
                cur.execute('''
                    INSERT INTO director ("CURP", "fecha_ingreso", "contrasena", "estado")
                    VALUES (%s, CURRENT_DATE, %s, 'Activo')
                    ON CONFLICT ("CURP") DO NOTHING
                ''', (DEFAULT_DIRECTOR['CURP'], default_hash))
                conn.commit()
                print("[INFO] Default director created successfully")
            except Exception as e:
                print(f"[WARNING] Error inserting director: {e}")
        else:
            # Director existe, verificar si el hash es correcto
            cur.execute('SELECT "contrasena" FROM director WHERE "CURP" = %s', (DEFAULT_DIRECTOR['CURP'],))
            result = cur.fetchone()
            if result:
                stored_hash = result[0]
                # Si el hash almacenado no es valid o es muy corto, actualizar
                if len(str(stored_hash)) < 100:
                    cur.execute('UPDATE director SET "contrasena" = %s WHERE "CURP" = %s',
                               (default_hash, DEFAULT_DIRECTOR['CURP']))
                    conn.commit()
                    print("[INFO] Updating director hash to default value")
        
        cur.close()
        conn.close()
    except Exception as e:
        print(f"[ERROR] ensure_default_director: {e}")

# Ejecutar al iniciar
ensure_default_director()

# ==========================================
# DECORADOR DE AUTENTICACIÓN
# ==========================================
def login_required(roles=None):
    """Decorador para requerir login y opcionalmente verificar roles"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if 'user_curp' not in session:
                return redirect(url_for('login'))
            
            if roles and session.get('user_role') not in roles:
                return "No autorizado", 403
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

# ==========================================
# FUNCIONES DE VALIDACIÓN
# ==========================================
def validar_curp(curp):
    """Valida formato CURP (18 caracteres)"""
    return bool(re.match(r'^[A-ZÑ]{4}\d{6}[HM][A-Z]{5}[0-9A-Z]\d$', curp.upper())) and len(curp) == 18

def validar_rfc(rfc):
    """Valida formato RFC (10-13 caracteres)"""
    return 10 <= len(rfc) <= 13

def validar_telefono(telefono):
    """Valida que el teléfono sea 7-15 dígitos"""
    return bool(re.match(r'^\d{7,15}$', telefono))

def find_role_by_curp(curp):
    """Encuentra el rol del usuario basado en su CURP"""
    try:
        conn = obtener_conexion()
        cur = conn.cursor()
        
        roles = ['director', 'coordinador', 'abogado', 'medico', 'psicologo', 'trabajadorsocial']
        
        for rol in roles:
            cur.execute(f'SELECT "CURP" FROM {rol} WHERE "CURP" = %s', (curp,))
            if cur.fetchone():
                cur.close()
                conn.close()
                return rol
        
        cur.close()
        conn.close()
        return None
    except Exception as e:
        print(f"[ERROR] find_role_by_curp: {e}")
        return None

# ==========================================
# RUTAS
# ==========================================
@app.route('/')
def inicio():
    """Ruta raíz - redirige a consultar o login"""
    if 'user_curp' in session:
        return redirect(url_for('consultar_personal'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Ruta de login"""
    if request.method == 'POST':
        correo = request.form.get('correo', '').strip()
        contrasena = request.form.get('contrasena', '')
        
        try:
            conn = obtener_conexion()
            cur = conn.cursor()
            
            # Buscar usuario en tabla persona por correo
            cur.execute('SELECT "CURP" FROM persona WHERE "correo" = %s', (correo,))
            persona_result = cur.fetchone()
            
            if not persona_result:
                return render_template('login.html', error='Correo o contraseña incorrectos')
            
            curp = persona_result[0]
            
            # Encontrar el rol del usuario
            rol = find_role_by_curp(curp)
            
            if not rol:
                return render_template('login.html', error='Usuario no tiene rol asignado')
            
            # Obtener contraseña del rol table
            cur.execute(f'SELECT "contrasena" FROM {rol} WHERE "CURP" = %s', (curp,))
            rol_result = cur.fetchone()
            
            if not rol_result:
                return render_template('login.html', error='Error al acceder a datos de usuario')
            
            stored_hash = rol_result[0]
            
            # Validar contraseña
            if check_password_hash(stored_hash, contrasena):
                session['user_curp'] = curp
                session['user_role'] = rol
                session.permanent = False
                
                cur.close()
                conn.close()
                
                if rol == 'director':
                    return redirect(url_for('registrar'))
                else:
                    return redirect(url_for('consultar_personal'))
            else:
                return render_template('login.html', error='Correo o contraseña incorrectos')
        
        except Exception as e:
            print(f"[ERROR] login: {e}")
            return render_template('login.html', error=f'Error: {str(e)}')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """Ruta de logout"""
    session.clear()
    return redirect(url_for('login'))

@app.route('/registrar-empleado', methods=['GET', 'POST'])
@login_required(roles=['director'])
def registrar():
    """Ruta para registrar nuevos empleados (solo acceso director)"""
    if request.method == 'POST':
        try:
            conn = obtener_conexion()
            cur = conn.cursor()
            
            # Obtener datos del formulario
            curp = request.form.get('curp', '').strip().upper()
            nombre = request.form.get('nombre', '').strip()
            apellido_p = request.form.get('apellidoP', '').strip()
            apellido_s = request.form.get('apellidoM', '').strip()
            rfc = request.form.get('rfc', '').strip().upper()
            sexo = request.form.get('sexo', 'Otro')
            fecha_nac = request.form.get('fecha_nacimiento', '')
            telefono = request.form.get('telefono', '').strip()
            correo = request.form.get('correo', '').strip().lower()
            direccion = request.form.get('calle', '').strip()
            cedula = request.form.get('cedula', '').strip()
            rol = request.form.get('rol', 'abogado').lower()
            especialidad = request.form.get('especialidad', '').strip()
            contrasena = request.form.get('contrasena', '').strip()
            
            # Validaciones
            if not validar_curp(curp):
                return render_template('registro.html', error='CURP inválido (18 caracteres)')
            
            if not validar_rfc(rfc):
                return render_template('registro.html', error='RFC inválido (10-13 caracteres)')
            
            if not validar_telefono(telefono):
                return render_template('registro.html', error='Teléfono inválido (7-15 dígitos)')
            
            # Insertar en tabla persona
            cur.execute('''
                INSERT INTO persona ("CURP", "RFC", "p_nombre", "s_nombre", "p_apellido", "s_apellido",
                                    "sexo", "fecha_nacimiento", "calle", "telefono", "correo")
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT ("CURP") DO UPDATE SET
                    "RFC" = EXCLUDED."RFC",
                    "p_nombre" = EXCLUDED."p_nombre",
                    "s_nombre" = EXCLUDED."s_nombre",
                    "p_apellido" = EXCLUDED."p_apellido",
                    "s_apellido" = EXCLUDED."s_apellido",
                    "sexo" = EXCLUDED."sexo",
                    "fecha_nacimiento" = EXCLUDED."fecha_nacimiento",
                    "calle" = EXCLUDED."calle",
                    "telefono" = EXCLUDED."telefono",
                    "correo" = EXCLUDED."correo"
            ''', (curp, rfc, nombre, '', apellido_p, apellido_s, sexo, fecha_nac, direccion, telefono, correo))
            conn.commit()
            
            # Insertar en tabla de rol específico
            if contrasena:
                hash_contrasena = generate_password_hash(contrasena)
            else:
                hash_contrasena = generate_password_hash('temporal123')
            
            if rol == 'abogado':
                cur.execute('''
                    INSERT INTO abogado ("cedula", "CURP", "especialidad", "contrasena", "estado")
                    VALUES (%s, %s, %s, %s, 'Activo')
                    ON CONFLICT ("cedula") DO UPDATE SET
                        "especialidad" = EXCLUDED."especialidad",
                        "contrasena" = EXCLUDED."contrasena"
                ''', (cedula, curp, especialidad, hash_contrasena))
            elif rol == 'medico':
                cur.execute('''
                    INSERT INTO medico ("cedula", "CURP", "especialidad", "contrasena", "estado")
                    VALUES (%s, %s, %s, %s, 'Activo')
                    ON CONFLICT ("cedula") DO UPDATE SET
                        "especialidad" = EXCLUDED."especialidad",
                        "contrasena" = EXCLUDED."contrasena"
                ''', (cedula, curp, especialidad, hash_contrasena))
            elif rol == 'psicologo':
                cur.execute('''
                    INSERT INTO psicologo ("cedula", "CURP", "enfoque_terapeutico", "contrasena", "estado")
                    VALUES (%s, %s, %s, %s, 'Activo')
                    ON CONFLICT ("cedula") DO UPDATE SET
                        "enfoque_terapeutico" = EXCLUDED."enfoque_terapeutico",
                        "contrasena" = EXCLUDED."contrasena"
                ''', (cedula, curp, especialidad, hash_contrasena))
            elif rol == 'trabajadorsocial':
                cur.execute('''
                    INSERT INTO trabajadorsocial ("cedula", "CURP", "contrasena", "estado")
                    VALUES (%s, %s, %s, 'Activo')
                    ON CONFLICT ("cedula") DO UPDATE SET
                        "contrasena" = EXCLUDED."contrasena"
                ''', (cedula, curp, hash_contrasena))
            
            conn.commit()
            cur.close()
            conn.close()
            
            print(f"[DEBUG] Nuevo {rol} registrado: {curp}")
            return render_template('registro.html', success='¡Empleado registrado exitosamente!')
        
        except Exception as e:
            print(f"[ERROR] registrar: {e}")
            return render_template('registro.html', error=f'Error al registrar: {str(e)}')
    
    return render_template('registro.html')

@app.route('/consultar-personal')
@login_required()
def consultar_personal():
    """Ruta para consultar personal (requiere login)"""
    try:
        conn = obtener_conexion()
        cur = conn.cursor()
        
        query = '''
            SELECT "CURP", "RFC", "p_nombre", "s_nombre", "p_apellido", "s_apellido", 
                   "sexo", "fecha_nacimiento", "calle", "telefono", "correo"
            FROM persona
            ORDER BY "p_apellido", "p_nombre"
        '''
        
        cur.execute(query)
        empleados = cur.fetchall()
        
        cur.close()
        conn.close()
        
        return render_template('consultar.html', empleados=empleados)
    except Exception as e:
        print(f"[ERROR] consultar_personal: {e}")
        return render_template('consultar.html', error=f'Error: {str(e)}')

if __name__ == '__main__':
    app.run(debug=True)