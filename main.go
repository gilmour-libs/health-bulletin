package main

import (
	"errors"
	"flag"
	"fmt"
	"gopkg.in/redis.v3"
	"os"
)

const BLANK = ""
const GilmourHealthKey = "gilmour.known_host.health"

func errExit(err error) {
	fmt.Println(err)
	os.Exit(2)
}

func newRedisClient(host string, port int) *redis.Client {
	// Create a new Redis connection.
	// If the ping errors out, prpgram will exit with status code 2

	client := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%v:%v", host, port),
		Password: "", // no password set
		DB:       0,  // use default DB
	})

	_, err := client.Ping().Result()
	if err != nil {
		errExit(err)
	}

	return client
}

func removeKey(client *redis.Client, ident string) {
	if ident == BLANK {
		err := errors.New("Identifier to remove cannot be blank")
		errExit(err)
	}

	intCmd := client.HDel(GilmourHealthKey, ident)
	err := intCmd.Err()
	if err != nil {
		errExit(err)
	}

	fmt.Printf("%v was successfully removed\n", ident)
}

func makeIdent(ident *string) {
	flag.StringVar(ident, "ident", "", "key to cleanup")
}

func makeRedisConf(host *string, port *int) {
	flag.StringVar(host, "host", "127.0.0.1", "Redis host to connect to")
	flag.IntVar(port, "port", 6379, "Redis port")
}

func main() {
	var ident string
	var redis_host string
	var redis_port int

	makeIdent(&ident)
	makeRedisConf(&redis_host, &redis_port)

	flag.Parse()

	client := newRedisClient(redis_host, redis_port)
	removeKey(client, ident)
	os.Exit(0) //Exit cleanly
}
