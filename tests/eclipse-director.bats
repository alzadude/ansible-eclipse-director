#!/usr/bin/env bats

@test "Module syntax" {
    bash -n ${BATS_TEST_DIRNAME}/../library/eclipse_director
}
