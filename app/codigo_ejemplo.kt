fun main() {
	val nombre = "Hola Mundo"
	val mensaje = saludar(nombre)

	println(mensaje)
}

fun saludar(nombre: String): String {
	return "Hola, $nombre!"
}
