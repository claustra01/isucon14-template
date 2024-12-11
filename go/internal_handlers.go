package main

import (
	"database/sql"
	"errors"
	"net/http"
	"time"
)

// このAPIをインスタンス内から一定間隔で叩かせることで、椅子とライドをマッチングさせる
func internalGetMatching(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	rideList := []Ride{}
	if err := db.SelectContext(ctx, &rideList, `SELECT * FROM rides WHERE chair_id IS NULL ORDER BY created_at`); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	chairList := []struct {
		ID          string    `db:"id"`
		OwnerID     string    `db:"owner_id"`
		Name        string    `db:"name"`
		Model       string    `db:"model"`
		IsActive    bool      `db:"is_active"`
		AccessToken string    `db:"access_token"`
		CreatedAt   time.Time `db:"created_at"`
		UpdatedAt   time.Time `db:"updated_at"`
		Latitude    int       `db:"latitude"`
		Longitude   int       `db:"longitude"`
	}{}
	query := `
		SELECT 
			c.*, 
			cl.latitude, 
			cl.longitude
		FROM 
			chairs c
		JOIN 
			chair_locations cl 
			ON c.id = cl.chair_id
		WHERE 
			c.is_active = TRUE
			AND cl.created_at = (
				SELECT MAX(created_at)
				FROM chair_locations
				WHERE chair_id = c.id
    );
	`
	if err := db.SelectContext(ctx, &chairList, query); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	for i := 0; i < len(chairList); i++ {
		chair := chairList[i]
		empty := false
		if err := db.GetContext(ctx, &empty, "SELECT COUNT(*) = 0 FROM (SELECT COUNT(chair_sent_at) = 6 AS completed FROM ride_statuses WHERE ride_id IN (SELECT id FROM rides WHERE chair_id = ?) GROUP BY ride_id) is_completed WHERE completed = FALSE", chair.ID); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		if !empty {
			continue
		}

		var nearestDistance int
		var nearestIndex int
		for j := 0; j < len(rideList); j++ {
			ride := rideList[j]
			distance := abs(ride.PickupLatitude-chair.Latitude) + abs(ride.PickupLongitude-chair.Longitude)
			if j == 0 || nearestDistance > distance {
				nearestDistance = distance
				nearestIndex = j
			}
		}

		if len(rideList) == 0 {
			break
		}
		ride := rideList[nearestIndex]
		if _, err := db.ExecContext(ctx, "UPDATE rides SET chair_id = ? WHERE id = ?", chair.ID, ride.ID); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		rideList = append(rideList[:nearestIndex], rideList[nearestIndex+1:]...)
	}

	w.WriteHeader(http.StatusNoContent)
}
