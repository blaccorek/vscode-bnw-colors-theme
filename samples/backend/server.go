// Package main is a sample Go program: structs, interfaces, goroutines, generics.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"sync"
	"time"
)

const (
	defaultAddr  = ":8080"
	maxRetries   = 3
	readTimeout  = 5 * time.Second
	writeTimeout = 10 * time.Second
)

var ErrNotFound = errors.New("not found")

type Role string

const (
	RoleAdmin  Role = "admin"
	RoleEditor Role = "editor"
	RoleViewer Role = "viewer"
)

type User struct {
	ID    int64    `json:"id"`
	Name  string   `json:"name"`
	Email string   `json:"email,omitempty"`
	Roles []Role   `json:"roles"`
	Meta  struct{} `json:"-"`
}

func (u User) HasRole(role Role) bool {
	for _, r := range u.Roles {
		if r == role {
			return true
		}
	}
	return false
}

type Repository[T any] interface {
	Get(ctx context.Context, id int64) (T, error)
	Save(ctx context.Context, id int64, item T) error
}

type memoryRepo[T any] struct {
	mu    sync.RWMutex
	items map[int64]T
}

func newMemoryRepo[T any]() *memoryRepo[T] {
	return &memoryRepo[T]{items: make(map[int64]T, 16)}
}

func (r *memoryRepo[T]) Get(_ context.Context, id int64) (T, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	item, ok := r.items[id]
	if !ok {
		var zero T
		return zero, fmt.Errorf("id %d: %w", id, ErrNotFound)
	}
	return item, nil
}

func (r *memoryRepo[T]) Save(ctx context.Context, id int64, item T) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	r.items[id] = item
	return nil
}

func Map[T, U any](in []T, fn func(T) U) []U {
	out := make([]U, 0, len(in))
	for _, v := range in {
		out = append(out, fn(v))
	}
	return out
}

func handler(repo Repository[User]) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), readTimeout)
		defer cancel()

		user, err := repo.Get(ctx, 1)
		switch {
		case errors.Is(err, ErrNotFound):
			http.Error(w, "no such user", http.StatusNotFound)
			return
		case err != nil:
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		if err := json.NewEncoder(w).Encode(user); err != nil {
			slog.Error("encode failed", "err", err)
		}
	}
}

func main() {
	repo := newMemoryRepo[User]()
	ctx := context.Background()

	var wg sync.WaitGroup
	results := make(chan string, maxRetries)

	for i := 1; i <= maxRetries; i++ {
		wg.Add(1)
		go func(n int) {
			defer wg.Done()
			u := User{ID: int64(n), Name: fmt.Sprintf("user-%02d", n), Roles: []Role{RoleViewer}}
			if err := repo.Save(ctx, u.ID, u); err != nil {
				results <- "error: " + err.Error()
				return
			}
			results <- u.Name
		}(i)
	}

	wg.Wait()
	close(results)

	names := make([]string, 0, maxRetries)
	for name := range results {
		names = append(names, name)
	}
	upper := Map(names, func(s string) string { return s + "!" })
	slog.Info("seeded", "names", upper, "count", len(upper))

	srv := &http.Server{
		Addr:         defaultAddr,
		Handler:      handler(repo),
		ReadTimeout:  readTimeout,
		WriteTimeout: writeTimeout,
	}
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		panic(err)
	}
}
