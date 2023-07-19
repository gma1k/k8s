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
	fmt.Println("Project ID, cluster name, zone, number of nodes")
	fmt.Print("-> ")
	input, err := reader.ReadString('\n')
	if err != nil {
		log.Fatal(err)
	}

	// Split the input by commas
	input = strings.TrimSpace(input)
	values := strings.Split(input, ",")
	if len(values) != 4 {
		log.Fatal("Invalid input format")
	}

	// Assign the values to variables
	projectID := values[0]
	clusterName := values[1]
	zone := values[2]
	numNodes := values[3]

	// Create a request to create a cluster
	req := &containerpb.CreateClusterRequest{
		ProjectId: projectID,
		Zone:      zone,
		Cluster: &containerpb.Cluster{
			Name:             clusterName,
			InitialNodeCount: numNodes,
			NodeConfig: &containerpb.NodeConfig{
				MachineType: "n1-standard-1",
			},
		},
	}

	// Call the create cluster method
	fmt.Println("Creating cluster...")
	op, err := client.CreateCluster(ctx, req)
	if err != nil {
		log.Fatal(err)
	}

	// Wait for the operation to finish
	fmt.Println("Waiting for operation to finish...")
	resp, err := op.Wait(ctx)
	if err != nil {
		log.Fatal(err)
	}

	// Print the response
	fmt.Printf("Cluster created: %v\n", resp)
}
