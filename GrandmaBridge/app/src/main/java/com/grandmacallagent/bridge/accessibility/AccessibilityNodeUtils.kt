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
            node.hintText?.toString()?.takeIf { it.isNotBlank() }?.let(results::add)
        }
        return results
    }

    fun findAcceptButton(root: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (root == null) return null
        return findClickableByExactLabels(root, ACCEPT_LABELS)
    }

    fun findClickableByExactLabels(root: AccessibilityNodeInfo?, labels: List<String>): AccessibilityNodeInfo? {
        if (root == null) return null
        val normalizedLabels = labels.map(::normalizeLabel).filter { it.isNotBlank() }.toSet()
        var result: AccessibilityNodeInfo? = null
        traverse(root) { node ->
            if (result != null) return@traverse
            val className = node.className?.toString().orEmpty()
            if (node.isEditable || className.contains("EditText", ignoreCase = true)) return@traverse
            val matched = nodeLabels(node).any { normalizeLabel(it) in normalizedLabels }
            if (matched && node.isEnabled) {
                result = firstClickableAncestor(node)
            }
        }
        return result
    }

    fun findEditableNodeByLabels(root: AccessibilityNodeInfo?, labels: List<String>): AccessibilityNodeInfo? {
        if (root == null) return null
        var result: AccessibilityNodeInfo? = null
        traverse(root) { node ->
            if (result != null) return@traverse
            val className = node.className?.toString().orEmpty()
            val isEditor = node.isEditable || className.contains("EditText", ignoreCase = true)
            val matches = labels.any { expected ->
                nodeLabels(node).any { actual -> actual.contains(expected, ignoreCase = true) }
            }
            if (node.isEnabled && isEditor && matches) {
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

    private fun nodeLabels(node: AccessibilityNodeInfo): List<String> {
        return listOfNotNull(
            node.text?.toString(),
            node.contentDescription?.toString(),
            node.hintText?.toString(),
        ).filter { it.isNotBlank() }
    }

    private fun normalizeLabel(value: String): String {
        return value.filterNot { it.isWhitespace() }.lowercase()
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
