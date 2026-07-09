package com.grandmacallagent.bridge.accessibility

import android.os.Bundle
import android.view.accessibility.AccessibilityNodeInfo

object AccessibilityNodeUtils {
    fun collectTexts(root: AccessibilityNodeInfo?): List<String> {
        if (root == null) return emptyList()
        val results = mutableListOf<String>()
        traverse(root) { node ->
            node.text?.toString()?.takeIf { it.isNotBlank() }?.let(results::add)
            node.contentDescription?.toString()?.takeIf { it.isNotBlank() }?.let(results::add)
        }
        return results
    }

    fun findAcceptButton(root: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (root == null) return null
        return findClickableByLabels(root, ACCEPT_LABELS)
    }

    fun findClickableByLabels(root: AccessibilityNodeInfo?, labels: List<String>): AccessibilityNodeInfo? {
        if (root == null) return null
        var result: AccessibilityNodeInfo? = null
        traverse(root) { node ->
            if (result != null) return@traverse
            val label = nodeLabel(node)
            val matched = labels.any { label.contains(it, ignoreCase = true) }
            if (matched && node.isEnabled) {
                result = firstClickableAncestor(node)
            }
        }
        return result
    }

    fun findEditableNode(root: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (root == null) return null
        var result: AccessibilityNodeInfo? = null
        traverse(root) { node ->
            if (result != null) return@traverse
            val className = node.className?.toString().orEmpty()
            if (node.isEnabled && (node.isEditable || className.contains("EditText", ignoreCase = true))) {
                result = node
            }
        }
        return result
    }

    fun setText(node: AccessibilityNodeInfo?, value: String): Boolean {
        if (node == null) return false
        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, value)
        }
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    private fun firstClickableAncestor(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var current: AccessibilityNodeInfo? = node
        repeat(6) {
            val candidate = current ?: return null
            if (candidate.isClickable && candidate.isEnabled) return candidate
            current = candidate.parent
        }
        return null
    }

    private fun nodeLabel(node: AccessibilityNodeInfo): String {
        return listOfNotNull(node.text?.toString(), node.contentDescription?.toString())
            .joinToString(" ")
    }

    private fun traverse(root: AccessibilityNodeInfo, visitor: (AccessibilityNodeInfo) -> Unit) {
        visitor(root)
        for (index in 0 until root.childCount) {
            root.getChild(index)?.let { child -> traverse(child, visitor) }
        }
    }

    private val ACCEPT_LABELS = listOf(
        "接听",
        "接受",
        "接通",
        "Answer",
        "Accept",
    )
}
