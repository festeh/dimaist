package main

import (
	"bufio"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"strings"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/calendar/v3"
)

func main() {
	credentialsFile := flag.String("credentials", "", "Path to OAuth credentials JSON file downloaded from Google Cloud Console")
	clientID := flag.String("client-id", "", "OAuth Client ID (alternative to credentials file)")
	clientSecret := flag.String("client-secret", "", "OAuth Client Secret (alternative to credentials file)")
	envFile := flag.String("env", ".env", "Path to .env file to update")
	port := flag.String("port", "8085", "Local port for OAuth callback")
	flag.Parse()

	var config *oauth2.Config
	redirectURL := fmt.Sprintf("http://localhost:%s/callback", *port)

	if *credentialsFile != "" {
		b, err := os.ReadFile(*credentialsFile)
		if err != nil {
			log.Fatalf("Failed to read credentials file: %v", err)
		}

		var creds struct {
			Installed struct {
				ClientID     string `json:"client_id"`
				ClientSecret string `json:"client_secret"`
			} `json:"installed"`
		}
		if err := json.Unmarshal(b, &creds); err != nil {
			log.Fatalf("Failed to parse credentials: %v", err)
		}

		config = &oauth2.Config{
			ClientID:     creds.Installed.ClientID,
			ClientSecret: creds.Installed.ClientSecret,
			Scopes:       []string{calendar.CalendarEventsScope},
			Endpoint:     google.Endpoint,
			RedirectURL:  redirectURL,
		}
	} else if *clientID != "" && *clientSecret != "" {
		config = &oauth2.Config{
			ClientID:     *clientID,
			ClientSecret: *clientSecret,
			Scopes:       []string{calendar.CalendarEventsScope},
			Endpoint:     google.Endpoint,
			RedirectURL:  redirectURL,
		}
	} else {
		fmt.Println("Google Calendar OAuth Token Generator")
		fmt.Println()
		fmt.Println("Usage:")
		fmt.Println("  Option 1: Use credentials JSON file from Google Cloud Console")
		fmt.Println("    ./google-auth -credentials=/path/to/credentials.json")
		fmt.Println()
		fmt.Println("  Option 2: Provide client ID and secret directly")
		fmt.Println("    ./google-auth -client-id=YOUR_ID -client-secret=YOUR_SECRET")
		fmt.Println()
		fmt.Println("Options:")
		fmt.Println("  -env=/path/to/.env    Path to .env file to update (default: .env)")
		fmt.Println("  -port=8085            Local port for OAuth callback (default: 8085)")
		fmt.Println()
		fmt.Println("Steps to get credentials:")
		fmt.Println("  1. Go to https://console.cloud.google.com")
		fmt.Println("  2. Create a project and enable Google Calendar API")
		fmt.Println("  3. Go to Credentials > Create OAuth 2.0 Client ID > Desktop app")
		fmt.Println("  4. Download JSON or copy client ID and secret")
		os.Exit(1)
	}

	// Channel to receive the authorization code
	codeChan := make(chan string)
	errChan := make(chan error)

	// Start local server to capture callback
	server := &http.Server{Addr: ":" + *port}
	http.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		code := r.URL.Query().Get("code")
		if code == "" {
			errChan <- fmt.Errorf("no code in callback")
			fmt.Fprintf(w, "<html><body><h1>Error</h1><p>No authorization code received.</p></body></html>")
			return
		}
		fmt.Fprintf(w, "<html><body><h1>Success!</h1><p>You can close this window.</p></body></html>")
		codeChan <- code
	})

	go func() {
		if err := server.ListenAndServe(); err != http.ErrServerClosed {
			errChan <- err
		}
	}()

	// Generate and open authorization URL
	url := config.AuthCodeURL("state-token", oauth2.AccessTypeOffline, oauth2.ApprovalForce)
	fmt.Println("Opening browser for authorization...")
	fmt.Println()
	fmt.Println("If browser doesn't open, visit this URL:")
	fmt.Println(url)
	fmt.Println()

	openBrowser(url)

	// Wait for the code
	var code string
	select {
	case code = <-codeChan:
		// Got the code
	case err := <-errChan:
		log.Fatalf("Error: %v", err)
	}

	// Shutdown the server
	server.Shutdown(context.Background())

	token, err := config.Exchange(context.Background(), code)
	if err != nil {
		log.Fatalf("Failed to exchange code for token: %v", err)
	}

	// Pretty print the full token
	out, _ := json.MarshalIndent(token, "", "  ")
	fmt.Println("Token obtained successfully!")
	fmt.Println()
	fmt.Println("Full token (for reference):")
	fmt.Println(string(out))

	// Update .env file
	envVars := map[string]string{
		"GOOGLE_CLIENT_ID":     config.ClientID,
		"GOOGLE_CLIENT_SECRET": config.ClientSecret,
		"GOOGLE_REFRESH_TOKEN": token.RefreshToken,
	}

	if err := updateEnvFile(*envFile, envVars); err != nil {
		log.Fatalf("Failed to update .env file: %v", err)
	}

	fmt.Println()
	fmt.Printf("Updated %s with Google credentials\n", *envFile)
}

func openBrowser(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "linux":
		cmd = exec.Command("xdg-open", url)
	case "darwin":
		cmd = exec.Command("open", url)
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	}
	if cmd != nil {
		cmd.Start()
	}
}

func updateEnvFile(path string, vars map[string]string) error {
	// Read existing content
	var lines []string
	existingKeys := make(map[string]int) // key -> line index

	if content, err := os.ReadFile(path); err == nil {
		scanner := bufio.NewScanner(strings.NewReader(string(content)))
		for scanner.Scan() {
			line := scanner.Text()
			lines = append(lines, line)

			// Track existing keys
			if idx := strings.Index(line, "="); idx > 0 {
				key := strings.TrimSpace(line[:idx])
				existingKeys[key] = len(lines) - 1
			}
		}
	}

	// Update or append variables
	for key, value := range vars {
		newLine := fmt.Sprintf("%s=%s", key, value)
		if idx, exists := existingKeys[key]; exists {
			lines[idx] = newLine
		} else {
			lines = append(lines, newLine)
		}
	}

	// Write back
	content := strings.Join(lines, "\n")
	if !strings.HasSuffix(content, "\n") {
		content += "\n"
	}

	return os.WriteFile(path, []byte(content), 0644)
}
