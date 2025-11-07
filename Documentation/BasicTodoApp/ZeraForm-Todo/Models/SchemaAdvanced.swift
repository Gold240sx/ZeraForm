//
//  Schema.swift
//  ZeraForm-Todo
//
//  Created by Michael Martell on 11/7/25.
//

import Foundation
import PowerSync
import ZyraForm


let MoodEnum = ZyraEnum(
    name: "mood_type",
    values: ["happy", "sad", "tired"]
)

let lists = ZyraTable(
    name: "lists_table",
    columns: [
        zf.text("name"),
        zf.uuid("owner_id"),
    ],
    rlsPolicies: [
        // Users can only access their own todos
        RLSPolicyBuilder(tableName: "todos").canAccessOwn()
    ]
)

let todos = ZyraTable(
    name: "todos_table",
    columns:  [
        zf.text("list_id"),
        zf.text("name"),
        zf.int("price"),
        zf.bool("purchased"),
        zf.url("link"),
        zf.text("mood").enum(MoodEnum).default("happy").notNull(),
        zf.timestampz("last-visited").default(.now),
    ],
    indexes: [
        Index(
            name: "list_id",
            columns: [IndexedColumn.ascending("list_id")]
        )
    ]
)

let AdvancedAppSchema = ZyraSchema(
    tables: [
        lists,
        todos
    ],
    enums: [
        MoodEnum
    ],
    dbPrefix: "ZyraForm-Demo-"
    
)


// id, created_at, and updated_at are all created automatically for every table
