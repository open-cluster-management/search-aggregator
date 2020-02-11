/*
IBM Confidential
OCO Source Materials
(C) Copyright IBM Corporation 2019 All Rights Reserved
The source code for this program is not published or otherwise divested of its trade secrets, irrespective of what has been deposited with the U.S. Copyright Office.
*/
package handlers

import (
	"testing"

	db "github.com/open-cluster-management/search-aggregator/pkg/dbconnector"
	rg "github.com/open-cluster-management/search-aggregator/pkg/dbconnector"
	"github.com/stretchr/testify/assert"
)

type MockCache struct {
}

func (mc MockCache) Query(input string) (rg.QueryResult, error) {
	res := [][]string{{"Header"}, {"100"}}
	return rg.QueryResult{Results: res}, nil
}

func TestNodeCount(t *testing.T) {
	fakeCache := MockCache{}
	db.Store = fakeCache
	count := computeNodeCount("anyinput")
	assert.Equal(t, 100, count)
}
