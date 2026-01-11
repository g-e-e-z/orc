package config

import "time"


type Config struct {
    Database DatabaseConfig
    Server   ServerConfig
    Engine   EngineConfig
}

type DatabaseConfig struct {
    Host     string
    Port     int
    User     string
    Password string
    DBName   string
}

type ServerConfig struct {
    Port            int
    ShutdownTimeout time.Duration
}

type EngineConfig struct {
    WorkerCount    int
    DefaultTimeout int // seconds
}

