package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	container "cloud.google.com/go/container/apiv1"
	containerpb "google.golang.org/genproto/googleapis/container/v1"
)

func main() {
	// Create a context
	ctx := context.Background()

	// Create a container client
	client, err := container.NewClusterManagerClient(ctx)
	if err != nil {
		log.Fatal(err)
	}
	defer client.Close()

	// Ask for user input
	reader := bufio.NewReader(os.Stdin)
	fmt.Println("Please enter the following values separated by commas:")
	fmt.Println("Project ID, cluster name, zone")
	fmt.Print("-> ")
	input, err := reader.ReadString('\n')
	if err != nil {
		log.Fatal(err)
	}

	// Split the input by commas
	input = strings.TrimSpace(input)
	values := strings.Split(input, ",")
	if len(values) != 3 {
		log.Fatal("Invalid input format")
	}

	// Assign the values to variables
	projectID := values[0]
	clusterName := values[1]
	zone := values[2]

	// Create a request to delete a cluster
	req := &containerpb.DeleteClusterRequest{
		Name: fmt.Sprintf("projects/%s/locations/%s/clusters/%s", projectID, zone, clusterName),
	}

	// Call the delete cluster method
	fmt.Println("Deleting cluster...")
	op, err := client.DeleteCluster(ctx, req)
	if err != nil {
		log.Fatal(err)
	}

	// Wait for the operation to finish
	fmt.Println("Waiting for operation to finish...")
	err = op.Wait(ctx)
	if err != nil {
		log.Fatal(err)
	}

	// Print the result
	fmt.Printf("Cluster deleted: %s\n", clusterName)
}
