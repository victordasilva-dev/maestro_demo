fun main() {
	val nombre = "Mundo"
	val mensaje = saludar(nombre)

	println(mensaje)
}

fun saludar(nombre: String): String {
	return "Hola, $nombre!"
}
