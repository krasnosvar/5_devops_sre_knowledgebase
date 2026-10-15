// Минимальный HTTP-сервер для Dockerfile.distroless
package main

import (
	"fmt"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "Hello from minimal container!")
	})
	http.ListenAndServe(":8080", nil)
}
