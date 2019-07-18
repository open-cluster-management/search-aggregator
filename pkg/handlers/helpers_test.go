/*
IBM Confidential
OCO Source Materials
5737-E67
(C) Copyright IBM Corporation 2019 All Rights Reserved
The source code for this program is not published or otherwise divested of its trade secrets, irrespective of what has been deposited with the U.S. Copyright Office.
*/
package handlers

import (
	"testing"

	rg "github.com/redislabs/redisgraph-go"
	"github.com/stretchr/testify/assert"
	db "github.ibm.com/IBMPrivateCloud/search-aggregator/pkg/dbconnector"
)

type MockCache struct {
}

func (mc MockCache) Query(input string) (rg.QueryResult, error) {
	dbhash := [][]string{{"Header"}, {"100"}, {"test3"}}
	return rg.QueryResult{Results: dbhash}, nil
}

func TestNodeCount(t *testing.T) {
	fakeCache := MockCache{}
	db.Store = fakeCache
	count := computeNodeCount("anyinput")
	assert.Equal(t, 100, count)
}
