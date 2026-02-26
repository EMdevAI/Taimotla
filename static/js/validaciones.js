function validarFormulario() {
    var curp = document.getElementById('curp').value;
    var telefono = document.getElementById('telefono').value;

    if (curp.length < 18) {
        alert("Error: La CURP debe tener exactamente 18 caracteres.");
        return false; 
    }

    if (isNaN(telefono)) {
        alert("El teléfono solo debe contener números.");
        return false;
    }

    return true;
}