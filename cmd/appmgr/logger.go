/*
==================================================================================
  Copyright (c) 2019 AT&T Intellectual Property.
  Copyright (c) 2019 Nokia

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
==================================================================================
*/

package main

import (
	"net/http"
	"time"
	mdclog "gerrit.o-ran-sc.org/r/com/golog"
)

type Log struct {
	logger *mdclog.MdcLogger
}

func NewLogger(name string) *Log {
	l, _ := mdclog.InitLogger(name)
	return &Log{
		logger: l,
	}
}

func (l *Log) SetLevel(level int) {
	l.logger.LevelSet(mdclog.Level(level))
}

func (l *Log) SetMdc(key string, value string) {
	l.logger.MdcAdd(key, value)
}

func (l *Log) Error(pattern string, args ...interface{}) {
	l.SetMdc("time", time.Now().Format("2019-01-02 15:04:05"))
	l.logger.Error(pattern, args...)
}

func (l *Log) Warn(pattern string, args ...interface{}) {
	l.SetMdc("time", time.Now().Format("2019-01-02 15:04:05"))
	l.logger.Warning(pattern, args...)
}

func (l *Log) Info(pattern string, args ...interface{}) {
	l.SetMdc("time", time.Now().Format("2019-01-02 15:04:05"))
	l.logger.Info(pattern, args...)
}

func (l *Log) Debug(pattern string, args ...interface{}) {
	l.SetMdc("time", time.Now().Format("2019-01-02 15:04:05"))
	l.logger.Debug(pattern, args...)
}

func LogRestRequests(inner http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		inner.ServeHTTP(w, r)
		Logger.Info("Logger: method=%s url=%s", r.Method, r.URL.RequestURI())
	})
}
