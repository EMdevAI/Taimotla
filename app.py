from flask import Flask, render_template, request, redirect, url_for
from database import obtener_conexion

app = Flask(__name__)
@app.route('/')
def inicio():
    
    return redirect(url_for('consultar_personal'))
@app.route('/registrar-empleado', methods=['GET', 'POST'])


@app.route('/registrar-empleado', methods=['GET', 'POST'])
def registrar():
    if request.method == 'POST':
        try:
            
            conn = obtener_conexion()
            cur = conn.cursor()
            
            rol = request.form['rol'].lower()
            datos = (
                request.form['cedula'], request.form['curp'],
                request.form['nombre'], request.form['apellidoP'],
                request.form['apellidoM'], request.form['telefono'],
                request.form['correo']
            )

            sql = f'INSERT INTO {rol} ("Cedula", "CURP", "nombre", "apellidoP", "apellidoM", "Telefono", "Correo") VALUES (%s, %s, %s, %s, %s, %s, %s)'
            cur.execute(sql, datos)
            conn.commit()
            cur.close()
            conn.close()

            return "<h1>¡Registro exitoso!</h1><a href='/registrar-empleado'>Volver</a>"

        except Exception as e:
            
            return f"<h1>Error al registrar</h1><p>{e}</p><a href='/registrar-empleado'>Intentar de nuevo</a>"

   
    return render_template('registro.html')


@app.route('/consultar-personal')
def consultar_personal():
    try:
        conn = obtener_conexion()
        cur = conn.cursor()
        
        # Usamos UNION para juntar los datos básicos de todas las tablas de profesionales
        # Añadimos una columna de texto para saber qué 'Rol' tienen
        query = """
            SELECT "nombre", "apellidoP", "apellidoM", "Cedula", 'Abogado' as rol FROM abogado
            UNION
            SELECT "nombre", "apellidoP", "apellidoM", "Cedula", 'Médico' as rol FROM medico
            UNION
            SELECT "nombre", "apellidoP", "apellidoM", "Cedula", 'Psicólogo' as rol FROM psicologo
            UNION
            SELECT "nombre", "apellidoP", "apellidoM", "Cedula", 'Trabajador Social' as rol FROM trabajadorsocial;
        """
        
        cur.execute(query)
        todos = cur.fetchall()
        
        cur.close()
        conn.close()
        
        return render_template('consultar.html', empleados=todos)
    except Exception as e:
        return f"<h1>Error al consultar</h1><p>{e}</p>"

if __name__ == '__main__':
    app.run(debug=True)