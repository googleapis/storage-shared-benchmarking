// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"context"
	"flag"
	"log"
	"os"

	"cloud.google.com/go/bigquery"
)

func main() {
	var projectID, datasetID, tableID, filename string
	flag.StringVar(&projectID, "p", "", "project")
	flag.StringVar(&datasetID, "d", "", "dataset")
	flag.StringVar(&tableID, "t", "", "table")
	flag.StringVar(&filename, "f", "", "filename")
	flag.Parse()
	ctx := context.Background()
	client, err := bigquery.NewClient(ctx, projectID)
	if err != nil {
		log.Fatalf("bigquery.NewClient: %v", err)
	}
	defer client.Close()
	f, err := os.Open(filename)
	if err != nil {
		log.Fatalf("os.Open: %v", err)
	}
	defer f.Close()
	tableRef := client.Dataset(datasetID).Table(tableID)
	// if err := tableRef.Create(ctx, &bigquery.TableMetadata{}); err != nil {
	// 	log.Printf("tableRef.Create(ignoring): %v", err)
	// }
	source := bigquery.NewReaderSource(f)
	source.AutoDetect = true   // Allow BigQuery to determine schema.
	source.SkipLeadingRows = 1 // CSV has a single header line.
	loader := tableRef.LoaderFrom(source)
	job, err := loader.Run(ctx)
	if err != nil {
		log.Fatalf("loader.Run: %v", err)
	}
	status, err := job.Wait(ctx)
	if err != nil {
		log.Fatalf("job.Wait: %v", err)
	}
	if err := status.Err(); err != nil {
		log.Fatalf("status.Err: %v", err)
	}
	log.Printf("Loaded CSV %v", filename)
}
