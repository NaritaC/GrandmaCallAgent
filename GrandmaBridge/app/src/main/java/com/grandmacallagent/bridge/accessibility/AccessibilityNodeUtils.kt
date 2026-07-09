package com.grandmacallagent.bridge.accessibility

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
        var result: AccessibilityNodeInfo? = null
        traverse(root) { node ->
            if (result != null) return@traverse
            val label = listOfNotNull(node.text?.toString(), node.contentDescription?.toString())
                .joinToString(" ")
            val isAcceptLabel = ACCEPT_LABELS.any { label.contains(it, ignoreCase = true) }
            if (isAcceptLabel && node.isEnabled) {
                result = firstClickableAncestor(node)
            }
        }
        return result
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
