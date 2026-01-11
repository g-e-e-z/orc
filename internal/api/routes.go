package api

import (
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"
)

func NewRouter() *chi.Mux {
	return chi.NewRouter()
}

func helloHandler(w http.ResponseWriter, r *http.Request){
	fmt.Fprintln(w, "Hello World")
}

