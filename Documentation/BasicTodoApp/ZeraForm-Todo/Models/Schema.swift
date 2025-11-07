//
//  Schema.swift
//  ZeraForm-Todo
//
//  Created by Michael Martell on 11/7/25.
//

import Foundation
import PowerSync
import ZyraForm


// Define the todo table schema
let todoTable = ZyraTable(
    name: "todos",
    // Optional: primaryKey: "id" // Defaults to id (which is a UUID type)
    columns: [
        zf.text("title").minLength(1).maxLength(200).notNull(),
        zf.text("description").nullable(),
        zf.text("is_completed").default("false").notNull(), // Boolean as text
        zf.text("user_id").notNull() // For multi-user support
    ],
    rlsPolicies: [
        // Users can only access their own todos
        RLSPolicyBuilder(tableName: "todos")
            .canAccessOwn()
    ]
)

let todoSchema = ZyraSchema(
    tables: [
        todoTable
    ],
    dbPrefix: ""
)
