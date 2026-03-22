package ai

import (
	"sync"
)

const maxSessions = 100

// SessionState holds the conversation state that survives connection drops.
type SessionState struct {
	ID               string
	Messages         []ChatCompletionMessage
	Targets          []TargetSpec
	SelectedModel    string
	IncludeCompleted bool
	CurrentProjectID *uint
	CurrentView      *string
	TurnID           int
}

// sessionStore keeps the last N sessions in memory, evicting oldest on overflow.
type sessionStore struct {
	mu    sync.Mutex
	items map[string]*SessionState
	order []string // insertion order for eviction
}

var store = &sessionStore{
	items: make(map[string]*SessionState),
}

// Save stores session state, evicting the oldest if at capacity.
func (s *sessionStore) Save(state *SessionState) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.items[state.ID]; !exists {
		// New session — check capacity
		for len(s.order) >= maxSessions {
			oldest := s.order[0]
			s.order = s.order[1:]
			delete(s.items, oldest)
		}
		s.order = append(s.order, state.ID)
	}
	s.items[state.ID] = state
}

// Load retrieves a session state by ID. Returns nil if not found.
func (s *sessionStore) Load(id string) *SessionState {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.items[id]
}
