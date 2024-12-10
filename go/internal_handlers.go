package main

import (
	"database/sql"
	"errors"
	"net/http"
)

// このAPIをインスタンス内から一定間隔で叩かせることで、椅子とライドをマッチングさせる
func internalGetMatching(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// MEMO: 一旦多対多でマッチングするようにしてみる。距離は考慮していないため後で改善後で改善する。
	rideList := []Ride{}
	if err := db.SelectContext(ctx, &rideList, `SELECT * FROM rides WHERE chair_id IS NULL ORDER BY created_at`); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	chairList := []Chair{}
	if err := db.SelectContext(ctx, &chairList, "SELECT * FROM chairs WHERE is_active = TRUE ORDER BY RAND()"); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	rideListIndex := 0
	for j := 0; j < len(chairList); j++ {
		matched := chairList[j]
		empty := false
		if err := db.GetContext(ctx, &empty, "SELECT COUNT(*) = 0 FROM (SELECT COUNT(chair_sent_at) = 6 AS completed FROM ride_statuses WHERE ride_id IN (SELECT id FROM rides WHERE chair_id = ?) GROUP BY ride_id) is_completed WHERE completed = FALSE", matched.ID); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		if !empty {
			continue
		}

		ride := rideList[rideListIndex]
		if _, err := db.ExecContext(ctx, "UPDATE rides SET chair_id = ? WHERE id = ?", matched.ID, ride.ID); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		rideListIndex++
		if rideListIndex >= len(rideList) {
			break
		}
	}

	w.WriteHeader(http.StatusNoContent)
}
