package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"
)

const (
	batchReports = 100
	batchBytes   = 600 << 10
	schema       = 1
)

type uploadBody struct {
	Schema    int      `json:"schema"`
	InstallID string   `json:"installId"`
	Uploader  string   `json:"uploader"`
	Reports   []Report `json:"reports"`
}

// UploadResult is the server's answer.
type UploadResult struct {
	OK         bool   `json:"ok"`
	Accepted   int    `json:"accepted"`
	Updated    int    `json:"updated"`
	Duplicates int    `json:"duplicates"`
	Error      string `json:"error"`
	Rejected   []struct {
		ID     string `json:"id"`
		Reason string `json:"reason"`
	} `json:"rejected"`
}

// RetryError says when to try again (429 / 5xx / network).
type RetryError struct {
	After time.Duration
	Err   error
}

func (e *RetryError) Error() string {
	return fmt.Sprintf("%v (retry in %s)", e.Err, e.After.Round(time.Second))
}

// FatalError is a refusal that retrying will not fix (bad key, bad request).
type FatalError struct{ Err error }

func (e *FatalError) Error() string { return e.Err.Error() }

type Uploader struct {
	Endpoint string
	Key      string
	Client   *http.Client
}

func NewUploader(endpoint, key string) *Uploader {
	return &Uploader{Endpoint: endpoint, Key: key, Client: &http.Client{Timeout: 45 * time.Second}}
}

// Batches splits reports so no request goes over the server's limits.
func Batches(rs []Report) [][]Report {
	var out [][]Report
	var cur []Report
	size := 0
	for _, r := range rs {
		b, _ := json.Marshal(r)
		if len(cur) > 0 && (len(cur) >= batchReports || size+len(b) > batchBytes) {
			out = append(out, cur)
			cur, size = nil, 0
		}
		cur = append(cur, r)
		size += len(b) + 1
	}
	if len(cur) > 0 {
		out = append(out, cur)
	}
	return out
}

// Send posts one batch for one install.
func (u *Uploader) Send(installID string, rs []Report) (*UploadResult, error) {
	body, err := json.Marshal(uploadBody{Schema: schema, InstallID: installID, Uploader: version, Reports: rs})
	if err != nil {
		return nil, &FatalError{err}
	}
	return u.Post(body)
}

// Post sends one prepared JSON body (v1 or the Sentinel v2 payload).
func (u *Uploader) Post(body []byte) (*UploadResult, error) {
	req, err := http.NewRequest(http.MethodPost, u.Endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, &FatalError{err}
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Phoenix-Key", u.Key)
	req.Header.Set("User-Agent", "PhoenixUploader/"+version+" (+https://vq8s.com/phoenix-ui)")
	res, err := u.Client.Do(req)
	if err != nil {
		return nil, &RetryError{After: time.Minute, Err: err}
	}
	defer res.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	var out UploadResult
	_ = json.Unmarshal(raw, &out)
	switch {
	case res.StatusCode == http.StatusOK && out.OK:
		return &out, nil
	case res.StatusCode == http.StatusTooManyRequests || res.StatusCode >= 500:
		after := 5 * time.Minute
		if s, err := strconv.Atoi(res.Header.Get("Retry-After")); err == nil && s > 0 {
			after = time.Duration(s) * time.Second
		}
		return nil, &RetryError{After: after, Err: fmt.Errorf("server said %d %s", res.StatusCode, msg(out, raw))}
	case res.StatusCode == http.StatusForbidden:
		return nil, &FatalError{errors.New("the ingest key was refused (403) - check ingestKey in config.json")}
	default:
		return nil, &FatalError{fmt.Errorf("server said %d %s", res.StatusCode, msg(out, raw))}
	}
}

func msg(r UploadResult, raw []byte) string {
	if r.Error != "" {
		return r.Error
	}
	if len(raw) > 200 {
		raw = raw[:200]
	}
	return string(raw)
}
